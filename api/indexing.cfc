<!---
*
* Copyright (C) 2005-2008 Razuna
*
* This file is part of Razuna - Enterprise Digital Asset Management.
*
* Razuna is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Razuna is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero Public License for more details.
*
* You should have received a copy of the GNU Affero Public License
* along with Razuna. If not, see <http://www.gnu.org/licenses/>.
*
* You may restribute this Program with a special exception to the terms
* and conditions of version 3.0 of the AGPL as described in Razuna's
* FLOSS exception. You should have received a copy of the FLOSS exception
* along with Razuna. If not, see <http://www.razuna.com/licenses/>.
*
--->
<cfcomponent output="false" extends="authentication">

	<!--- Index Files --->
	<cffunction name="indexFiles" access="public" output="false">
		<!--- Enable Log --->
		<cfset consoleoutput(true)>
		<!--- Get Config --->
		<cfset var config = getConfig()>
		<!--- Log --->
		<cfset console("#now()# ---------------------- Starting indexing")>
		<!--- Get all hosts to index. This will abort if nothing found. --->
		<cfset var qryAllHostsAndFiles = _getHosts(prefix=config.conf_db_prefix, dbtype=config.conf_db_type) />
		<!--- Check for lock file. This return a new qry with hosts that can be processed --->
		<cfset var _qryNew = _lockFile(qryAllHostsAndFiles) />
		<!--- Download doc files if cloud based --->
		<cfif config.conf_storage EQ "amazon">
			<cfset _getFilesInCloud(_qryNew) />
		</cfif>
		<!--- Index File --->
		<cfset _doIndex( qryfiles = _qryNew, storage = config.conf_storage, thedatabase = config.conf_db_type ) />
		<!--- Update database and flush cache --->
		<cfset _updateDb(qryfiles = _qryNew) />
		<!--- Remove lock file --->
		<cfset _removeLockFile(_qryNew) />			
		<!--- If cloud based remove the temp doc storage --->
		<cfif config.conf_storage EQ "amazon">
			<cfset _removeTempDocStore(_qryNew) />
		</cfif>
		<!--- Log --->
		<cfset console("#now()# ---------------------- Indexing done!!!!")>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- Index Files --->
	<cffunction name="removeFiles" access="public" output="false">
		<!--- Enable Log --->
		<cfset consoleoutput(true)>
		<!--- Log --->
		<cfset console("#now()# ---------------------- Starting removal")>
		<!--- Grab records to remove --->
		<cfset var _qryRecords = _qryRemoveRecords()>
		<!--- Remove records in Lucene --->
		<cfset _removeFromIndex(_qryRecords)>
		<!--- All done remove records in database --->
		<cfset _removeFromDatabase(_qryRecords)>
		<!--- Log --->
		<cfset console("#now()# ---------------------- Finished removal")>
		<!--- Return --->
		<cfreturn />
	</cffunction>


	<!--- PRIVATE --->

	<!--- lock File --->
	<cffunction name="_lockFile" access="private" returntype="query">
		<cfargument name="qry" required="true" type="query">
		<!--- Indexing --->
		<cfset var _hosts = ListRemoveDuplicates(valuelist(arguments.qry.host_id)) />
		<!--- Put query into var --->
		<cfset var _newQry = arguments.qry />
		<!--- Group all hosts (since the qry is per file) --->
		<cfloop list="#_hosts#" delimiters="," index="host_id">
			<!--- Check that collection exists --->
			<cfinvoke component="collection" method="checkCollection" hostid="#host_id#" />
			<!--- Log --->
			<cfset console("#now()# ---------------------- Checking the lock file for Collection: #host_id#")>
			<!--- Name of lock file --->
			<cfset var lockfile = "lucene_#host_id#.lock">
			<!--- Check if lucene.lock file exists and a) If it is older than a day then delete it or b) if not older than a day them abort as its probably running from a previous call --->
			<cfset var lockfilepath = "#GetTempDirectory()#/#lockfile#">
			<cfset var lockfiledelerr = false>
			<cfif fileExists(lockfilepath) >
				<cfset var lockfiledate = getfileinfo(lockfilepath).lastmodified>
				<cfif datediff("n", lockfiledate, now()) GT 5>
					<cftry>
						<cffile action="delete" file="#lockfilepath#">
						<cfcatch><cfset lockfiledelerr = true></cfcatch> <!--- Catch any errors on file deletion --->
					</cftry>
				<cfelse>
					<cfset lockfiledelerr = true>
				</cfif>
			</cfif>
			<!--- If error on lock file deletion then abort as file is probably still being used for indexing --->
			<cfif lockfiledelerr>
				<!--- Log --->
				<cfset console("#now()# ---------------------- Lock file for Collection: #host_id# exists. Skipping this host for now!")>
				<!--- Select without this host --->
				<cfquery dbtype="query" name="_newQry">
				SELECT *
				FROM _newQry
				WHERE host_id != #host_id#
				</cfquery>
			<cfelse>
				<!--- Log --->
				<cfset console("#now()# ---------------------- Lock file created for: #host_id#")>
				<!--- We are all good write file --->
				<cffile action="write" file="#GetTempDirectory()#/#lockfile#" output="x" mode="775" />
			</cfif>
		</cfloop>
		<!--- Only continue if records are found --->
		<cfif _newQry.recordcount NEQ 0>
			<!--- Log --->
			<cfset console("#now()# ---------------------- Found #_newQry.recordcount# consolidated records to index.")>
		<cfelse>
			<!--- Log --->
			<cfset console("#now()# ---------------------- Found #_newQry.recordcount# consolidated records to index. Aborting...")>
			<!--- Remove lock file --->
			<!--- <cfset _removeLockFile(arguments.qry) /> --->
			<!--- Abort --->
			<cfabort>
		</cfif>
		<!--- Return --->
		<cfreturn _newQry />
	</cffunction>

	<!--- Remove lock file --->
	<cffunction name="_removeLockFile" access="private">
		<cfargument name="qry" required="true" type="query">
		<!--- Valuelist hosts --->
		<cfset var _hosts = ListRemoveDuplicates(valuelist(arguments.qry.host_id)) />
		<!--- Loop over hosts --->
		<cfloop list="#_hosts#" delimiters="," index="host_id">
			<cftry>
				<!--- Log --->
				<cfset console("#now()# ---------------------- Removing lock file of Host: #host_id#")>
				<!--- Name of lock file --->
				<cfset var lockfile = "lucene_#host_id#.lock">
				<!--- Action --->
				<cfif fileExists("#GetTempDirectory()#/#lockfile#")>
					<cffile action="delete" file="#GetTempDirectory()#/#lockfile#" />
				</cfif>
				<cfcatch type="any">
					<cfset console("#now()# ---------------------- ERROR removing lock file for Host: #host_id#")>
					<cfset console(cfcatch)>
				</cfcatch>
			</cftry>
		</cfloop>
		<!--- Return --->
		<cfreturn />
	</cffunction>
	
	<!--- Get all hosts --->
	<cffunction name="_getHosts" access="private">
		<cfargument name="prefix" required="true">
		<cfargument name="dbtype" required="true">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Grabing hosts and files for indexing")>
		<!--- Var --->
		<cfset var qry = "" />
		<cfset var howmany = 1000 />
		<!--- Loop over prefix --->
		<cfloop list="#arguments.prefix#" index="prefix" delimiters=",">
			<!--- Query hosts --->
			<cfquery datasource="#application.razuna.datasource#" name="qry">
			SELECT<cfif arguments.dbtype EQ "mssql"> TOP #howmany#</cfif> i.host_id as host_id, h.host_shard_group as prefix, i.img_id as file_id, 'img' as category, 'T' as notfile
			FROM #prefix#images i, hosts h
			WHERE i.host_id = h.host_id
			AND i.is_indexed = <cfqueryparam cfsqltype="cf_sql_varchar" value="0">
			AND ( h.host_shard_group IS NOT NULL OR h.host_shard_group != '' )
			<cfif cgi.http_host CONTAINS "razuna.com">
				AND h.host_type != 0
			</cfif>
			<cfif arguments.dbtype NEQ "mssql">LIMIT #howmany#</cfif>
			UNION ALL
			SELECT<cfif arguments.dbtype EQ "mssql"> TOP #howmany#</cfif> f.host_id as host_id, h.host_shard_group as prefix, f.file_id as file_id, 'doc' as category, 'F' as notfile
			FROM #prefix#files f, hosts h
			WHERE f.host_id = h.host_id		
			AND f.is_indexed = <cfqueryparam cfsqltype="cf_sql_varchar" value="0">
			AND ( h.host_shard_group IS NOT NULL OR h.host_shard_group != '' )
			<cfif cgi.http_host CONTAINS "razuna.com">
				AND h.host_type != 0
			</cfif>
			<cfif arguments.dbtype NEQ "mssql">LIMIT #howmany#</cfif>
			UNION ALL
			SELECT<cfif arguments.dbtype EQ "mssql"> TOP #howmany#</cfif> v.host_id as host_id, h.host_shard_group as prefix, v.vid_id as file_id, 'vid' as category, 'T' as notfile
			FROM #prefix#videos v, hosts h
			WHERE v.host_id = h.host_id		
			AND v.is_indexed = <cfqueryparam cfsqltype="cf_sql_varchar" value="0">
			AND ( h.host_shard_group IS NOT NULL OR h.host_shard_group != '' )
			<cfif cgi.http_host CONTAINS "razuna.com">
				AND h.host_type != 0
			</cfif>
			<cfif arguments.dbtype NEQ "mssql">LIMIT #howmany#</cfif>
			UNION ALL
			SELECT<cfif arguments.dbtype EQ "mssql"> TOP #howmany#</cfif> a.host_id as host_id, h.host_shard_group as prefix, a.aud_id as file_id, 'aud' as category, 'T' as notfile
			FROM #prefix#audios a, hosts h
			WHERE a.host_id = h.host_id		
			AND a.is_indexed = <cfqueryparam cfsqltype="cf_sql_varchar" value="0">
			AND ( h.host_shard_group IS NOT NULL OR h.host_shard_group != '' )
			<cfif cgi.http_host CONTAINS "razuna.com">
				AND h.host_type != 0
			</cfif>
			<cfif arguments.dbtype NEQ "mssql">LIMIT #howmany#</cfif>
			</cfquery>
		</cfloop>
		<!--- Only continue if records are found --->
		<cfif qry.recordcount NEQ 0>
			<!--- Log --->
			<cfset console("#now()# ---------------------- Found #qry.recordcount# records to index")>
		<cfelse>
			<!--- Log --->
			<cfset console("#now()# ---------------------- Found #qry.recordcount# records to index. Aborting...")>
			<cfabort>
		</cfif>
		<!--- Return --->
		<cfreturn qry />
	</cffunction>

	<!--- Get all assets for Lucene Rebuilding --->
	<cffunction name="_getFilesInCloud" output="false" returntype="void" access="private">
		<cfargument name="qry" type="query" required="true">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Grabing all DOC files and storing them locally")>
		<!--- Params --->
		<cfset var docpath = GetTempDirectory() & "reindex_" & createuuid("")>
		<!--- Create a temp folder for the documents --->
		<cfdirectory action="create" directory="#docpath#" mode="775">
		<!--- Loop over records and only download for docs --->
		<cfloop query="arguments.qry">
			<cfif link_kind NEQ "url" AND cat EQ "doc">
				<!--- Download --->
				<cfif cloud_url_org CONTAINS "://">
					<cfhttp url="#cloud_url_org#" file="#file_name_org#" path="#docpath#"></cfhttp>
				</cfif>
				<!--- If download was successful --->
				<cfif fileexists("#docpath#/#file_name_org#")>
					<!--- Update file DB with new lucene_key --->
					<cfquery datasource="#application.razuna.datasource#">
					UPDATE #prefix#files
					SET lucene_key = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#docpath#/#file_name_org#">
					WHERE file_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#file_id#">
					</cfquery>
				</cfif>
			</cfif>
		</cfloop>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- Remove all doc file if in cloud --->
	<cffunction name="_removeTempDocStore" output="false" returntype="void" access="private">
		<cfargument name="qry" type="query" required="true">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Removing the temp doc store")>
		<!--- List files in temp --->
		<cfset var dirlist = DirectoryList( GetTempDirectory(), false, "path" ) >
		<!--- Loop over array --->
		<cfloop array="#dirlist#" index="a">
			<cfif a CONTAINS "reindex_">
				<cftry>
					<cfset directoryDelete(a)/>
					<cfcatch>
					</cfcatch>
				</cftry>
			</cfif>
		</cfloop>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- INDEX: Update --->
	<cffunction name="_doIndex" access="public" output="false">
		<cfargument name="qryfiles" required="true" type="query">
		<cfargument name="storage" required="true" type="string">
		<cfargument name="thedatabase" required="true" type="string">
		<!--- Params --->
		<cfset var folderpath = "">
		<!--- <cfset var theregchars = "[\&\(\)\[\]\'\n\r]+"> --->
		<cfset var theregchars = "[\$\%\_\-\,\.\&\(\)\[\]\*\n\r]+">
		<cfset var thedesc = "">
		<cfset var thekeys = "">
		<!--- Create the qoq_img --->
		<cfset var qoq_img = queryNew("collection, id, folder, filename, filenameorg, link_kind, lucene_key, description, keywords,
				theext, extension, rawmetadata, category, subjectcode, creator, title, authorsposition, captionwriter, ciadrextadr, xmp_category, 
				supplementalcategories, urgency, ciadrcity, ciadrctry, location, ciadrpcode, ciemailwork, ciurlwork, citelwork, 
				intellectualgenre, instructions, source, usageterms, copyrightstatus, transmissionreference, webstatement, headline, 
				datecreated, city, ciadrregion, country, countrycode, scene, state, credit, rights, labels, 
				customfieldvalue, folderpath, host_id") />
		<!--- Create the qoq_vid --->
		<cfset var qoq_vid = queryNew("collection, id, folder, filename, filenameorg, link_kind, lucene_key, description, keywords, rawmetadata, thecategory, category,
				theext, labels, customfieldvalue, folderpath, host_id") />
		<!--- Create the qoq_aud --->
		<cfset var qoq_aud = queryNew("collection, id, folder, filename, filenameorg, link_kind, lucene_key, description, keywords, rawmetadata, thecategory, category,
				theext, labels, customfieldvalue, folderpath, host_id") />
		<!--- Create the qoq_doc --->
		<cfset var qoq_doc = queryNew("collection, id, folder, filename, filenameorg, link_kind, lucene_key, description, keywords, rawmetadata, thecategory, category,
				theext, labels, customfieldvalue, folderpath, author, rights, authorsposition, captionwriter, webstatement, rightsmarked, thekey, host_id") />
				
		<!--- Loop over records --->
		<cfloop query="arguments.qryfiles">
			<!--- Log --->
			<cfset console("#now()# ---------------------- Starting to index file: #file_id# (#category#) for host: #host_id#")>
			<!--- Images --->
			<cfif category EQ "img">
				<!--- Query --->
				<cfset var qry_img = _getImages(hostid = host_id, prefix = prefix, file_id = file_id) />
				<!--- FolderPath --->
				<cfset var folderpath_img = _folderPath(hostid = host_id, prefix = prefix, folder = qry_img.folder) />
				<!--- Custom Fields --->
				<cfset var cf_img = _getCustomFields(hostid = host_id, prefix = prefix, file_id = file_id, thedatabase = arguments.thedatabase, category = "images") />
				<!--- Labels --->
				<cfset var labels_img = _getLabels(hostid = host_id, prefix = prefix, file_id = file_id, category = "images") />
				<!--- Remove foreign chars for some columns --->
				<cfset var thefilename = REReplaceNoCase(qry_img.filename, "'", "", "ALL")><!--- For single quotes remove them instead of replacing with space --->
				<cfset var thefilename = REReplaceNoCase(thefilename, theregchars, " ", "ALL")>
				<!--- Loop over the qry_img set because we could have more then one language for the description and keywords --->
				<cfloop query="qry_img">
					<!--- For single quotes remove them instead of replacing with space --->
					<cfset var thedesc_1 = REReplaceNoCase(description, "'", "", "ALL") >
					<cfset var thekeys_1 = REReplaceNoCase(keywords,  "'", "", "ALL")>
					<cfset var thedesc = REReplaceNoCase(thedesc_1 , theregchars, " ", "ALL") & " " & thedesc>
					<cfset var thekeys = REReplaceNoCase(thekeys_1, theregchars, " ", "ALL") & " " & thekeys>
				</cfloop>
				<!--- Struct for adding to qoq_img --->
				<cfset var q = {
					collection : qry_img.collection,
					id : qry_img.id,
					folder : qry_img.folder,  
					filename : 	'#thefilename# #qry_img.filename#',
					filenameorg : qry_img.filenameorg,
					link_kind : qry_img.link_kind,
					lucene_key : qry_img.lucene_key,
					description : '#thedesc#',
					keywords : '#thekeys#',
					theext : qry_img.theext,
					extension : qry_img.theext,
					rawmetadata : qry_img.rawmetadata,
					category : qry_img.category,
					subjectcode : qry_img.subjectcode,
					creator : qry_img.creator,
					title : qry_img.title,
					authorsposition : qry_img.authorsposition,
					captionwriter : qry_img.captionwriter,
					ciadrextadr : qry_img.ciadrextadr,
					xmp_category : qry_img.xmp_category,
					supplementalcategories : qry_img.supplementalcategories,
					urgency : qry_img.urgency,
					ciadrcity : qry_img.ciadrcity,
					ciadrctry : qry_img.ciadrctry,
					location : qry_img.location,
					ciadrpcode : qry_img.ciadrpcode,
					ciemailwork : qry_img.ciemailwork,
					ciurlwork : qry_img.ciurlwork,
					citelwork : qry_img.citelwork,
					intellectualgenre : qry_img.intellectualgenre,
					instructions : qry_img.instructions,
					source : qry_img.source,
					usageterms : qry_img.usageterms,
					copyrightstatus : qry_img.copyrightstatus,
					transmissionreference : qry_img.transmissionreference,
					webstatement : qry_img.webstatement,
					headline : qry_img.headline,
					datecreated : qry_img.datecreated,
					city : qry_img.city,
					ciadrregion : qry_img.ciadrregion,
					country : qry_img.country,
					countrycode : qry_img.countrycode,
					scene : qry_img.scene,
					state : qry_img.state,
					credit : qry_img.credit,
					rights : qry_img.rights,
					labels : '#labels_img#',
					customfieldvalue : '#REReplace(cf_img,"#chr(13)#|#chr(9)#|\n|\r","","ALL")#',
					folderpath : '#folderpath_img#',
					host_id : '#host_id#'
				} />
				<!--- Add result to qoq_img --->
				<cfset QueryAddrow(query = qoq_img, data = q) />
				<!--- Log --->
				<cfset console("#now()# ---------------------- Added file #file_id# (#category#) for host: #host_id# to QoQ")>
			<!--- Docs --->
			<cfelseif category EQ "doc">
				<!--- Query --->
				<cfset var qry_doc = _getDocs(hostid = host_id, prefix = prefix, file_id = file_id, notfile = notfile, storage = arguments.storage) />
				<!--- FolderPath --->
				<cfset var folderpath_doc = _folderPath(hostid = host_id, prefix = prefix, folder = qry_doc.folder) />
				<!--- Custom Fields --->
				<cfset var cf_doc = _getCustomFields(hostid = host_id, prefix = prefix, file_id = file_id, thedatabase = arguments.thedatabase, category = "files") />
				<!--- Labels --->
				<cfset var labels_doc = _getLabels(hostid = host_id, prefix = prefix, file_id = file_id, category = "files") />
				<!--- Remove foreign chars for some columns --->
				<cfset var thefilename = REReplaceNoCase(qry_doc.filename, "'", "", "ALL")><!--- For single quotes remove them instead of replacing with space --->
				<cfset var thefilename = REReplaceNoCase(thefilename, theregchars, " ", "ALL")>
				<!--- Loop over the qry_all set because we could have more then one language for the description and keywords --->
				<cfloop query="qry_doc">
					<!--- For single quotes remove them instead of replacing with space --->
					<cfset var thedesc_1 = REReplaceNoCase(description, "'", "", "ALL") >
					<cfset var thekeys_1 = REReplaceNoCase(keywords,  "'", "", "ALL")>
					<cfset var thedesc = REReplaceNoCase(thedesc_1 , theregchars, " ", "ALL") & " " & thedesc>
					<cfset var thekeys = REReplaceNoCase(thekeys_1, theregchars, " ", "ALL") & " " & thekeys>
				</cfloop>
				<!--- Struct for adding to qoq_img --->
				<cfset var q = {
					collection : qry_doc.collection,
					id : qry_doc.id,
					thekey : qry_doc.thekey,
					folder : qry_doc.folder,
					category : qry_doc.category,
					filename : 	'#thefilename# #qry_doc.filename#',
					filenameorg : qry_doc.filenameorg,
					link_kind : qry_doc.link_kind,
					lucene_key : qry_doc.lucene_key,
					description : '#thedesc#',
					keywords : '#thekeys#',
					rawmetadata : qry_doc.rawmetadata,
					thecategory : qry_doc.thecategory,
					theext : qry_doc.theext,
					labels : '#labels_doc#',
					customfieldvalue : '#REReplace(cf_doc,"#chr(13)#|#chr(9)#|\n|\r","","ALL")#',
					folderpath : '#folderpath_doc#',
					author : qry_doc.author, 
					rights : qry_doc.rights, 
					authorsposition : qry_doc.authorsposition, 
					captionwriter : qry_doc.captionwriter, 
					webstatement : qry_doc.webstatement, 
					rightsmarked : qry_doc.rightsmarked,
					host_id : '#host_id#'
				} />
				<!--- Add result to qoq_doc --->
				<cfset QueryAddrow(query = qoq_doc, data = q) />
				<!--- Log --->
				<cfset console("#now()# ---------------------- Added file #file_id# (#category#) for host: #host_id# to QoQ")>
			<!--- Videos --->
			<cfelseif category EQ "vid">
				<!--- Query --->
				<cfset var qry_vid = _getVideos(hostid = host_id, prefix = prefix, file_id = file_id) />
				<!--- FolderPath --->
				<cfset var folderpath_vid = _folderPath(hostid = host_id, prefix = prefix, folder = qry_vid.folder) />
				<!--- Custom Fields --->
				<cfset var cf_vid = _getCustomFields(hostid = host_id, prefix = prefix, file_id = file_id, thedatabase = arguments.thedatabase, category = "videos") />
				<!--- Labels --->
				<cfset var labels_vid = _getLabels(hostid = host_id, prefix = prefix, file_id = file_id, category = "videos") />
				<!--- Remove foreign chars for some columns --->
				<cfset var thefilename = REReplaceNoCase(qry_vid.filename, "'", "", "ALL")><!--- For single quotes remove them instead of replacing with space --->
				<cfset var thefilename = REReplaceNoCase(thefilename, theregchars, " ", "ALL")>
				<!--- Loop over the qry_all set because we could have more then one language for the description and keywords --->
				<cfloop query="qry_vid">
					<!--- For single quotes remove them instead of replacing with space --->
					<cfset var thedesc_1 = REReplaceNoCase(description, "'", "", "ALL") >
					<cfset var thekeys_1 = REReplaceNoCase(keywords,  "'", "", "ALL")>
					<cfset var thedesc = REReplaceNoCase(thedesc_1 , theregchars, " ", "ALL") & " " & thedesc>
					<cfset var thekeys = REReplaceNoCase(thekeys_1, theregchars, " ", "ALL") & " " & thekeys>
				</cfloop>
				<!--- Struct for adding to qoq_img --->
				<cfset var q = {
					collection : qry_vid.collection,
					id : qry_vid.id,
					folder : qry_vid.folder,
					category : qry_vid.category,
					filename : 	'#thefilename# #qry_vid.filename#',
					filenameorg : qry_vid.filenameorg,
					link_kind : qry_vid.link_kind,
					lucene_key : qry_vid.lucene_key,
					description : '#thedesc#',
					keywords : '#thekeys#',
					rawmetadata : qry_vid.rawmetadata,
					thecategory : qry_vid.thecategory,
					theext : qry_vid.theext,
					labels : '#labels_vid#',
					customfieldvalue : '#REReplace(cf_vid,"#chr(13)#|#chr(9)#|\n|\r","","ALL")#',
					folderpath : '#folderpath_vid#',
					host_id : '#host_id#'
				} />
				<!--- Add result to qoq_img --->
				<cfset QueryAddrow(query = qoq_vid, data = q) />
				<!--- Log --->
				<cfset console("#now()# ---------------------- Added file #file_id# (#category#) for host: #host_id# to QoQ")>
			<!--- Audios --->
			<cfelseif category EQ "aud">
				<!--- Query --->
				<cfset var qry_aud = _getAudios(hostid = host_id, prefix = prefix, file_id = file_id) />
				<!--- FolderPath --->
				<cfset var folderpath_aud = _folderPath(hostid = host_id, prefix = prefix, folder = qry_aud.folder) />
				<!--- Custom Fields --->
				<cfset var cf_aud = _getCustomFields(hostid = host_id, prefix = prefix, file_id = file_id, thedatabase = arguments.thedatabase, category = "audios") />
				<!--- Labels --->
				<cfset var labels_aud = _getLabels(hostid = host_id, prefix = prefix, file_id = file_id, category = "audios") />
				<!--- Remove foreign chars for some columns --->
				<cfset var thefilename = REReplaceNoCase(qry_aud.filename, "'", "", "ALL")><!--- For single quotes remove them instead of replacing with space --->
				<cfset var thefilename = REReplaceNoCase(thefilename, theregchars, " ", "ALL")>
				<!--- Loop over the qry_all set because we could have more then one language for the description and keywords --->
				<cfloop query="qry_aud">
					<!--- For single quotes remove them instead of replacing with space --->
					<cfset var thedesc_1 = REReplaceNoCase(description, "'", "", "ALL") >
					<cfset var thekeys_1 = REReplaceNoCase(keywords,  "'", "", "ALL")>
					<cfset var thedesc = REReplaceNoCase(thedesc_1 , theregchars, " ", "ALL") & " " & thedesc>
					<cfset var thekeys = REReplaceNoCase(thekeys_1, theregchars, " ", "ALL") & " " & thekeys>
				</cfloop>
				<!--- Struct for adding to qoq_aud --->
				<cfset var q = {
					collection : qry_aud.collection,
					id : qry_aud.id,
					folder : qry_aud.folder,
					category : qry_aud.category,
					filename : 	'#thefilename# #qry_aud.filename#',
					filenameorg : qry_aud.filenameorg,
					link_kind : qry_aud.link_kind,
					lucene_key : qry_aud.lucene_key,
					description : '#thedesc#',
					keywords : '#thekeys#',
					rawmetadata : qry_aud.rawmetadata,
					thecategory : qry_aud.thecategory,
					theext : qry_aud.theext,
					labels : '#labels_aud#',
					customfieldvalue : '#REReplace(cf_aud,"#chr(13)#|#chr(9)#|\n|\r","","ALL")#',
					folderpath : '#folderpath_aud#',
					host_id : '#host_id#'
				} />
				<!--- Add result to qoq_img --->
				<cfset QueryAddrow(query = qoq_aud, data = q) />
				<!--- Log --->
				<cfset console("#now()# ---------------------- Added file #file_id# (#category#) for host: #host_id# to QoQ")>
			</cfif>
			<cfset var q = "">
			<cfset var thedesc_1 = "">
			<cfset var thekeys_1 = "">
			<cfset var thedesc = "">
			<cfset var thekeys = "">
		</cfloop>

		<!--- We should have all the QoQ together now. Insert into Lucene --->

		<!--- Images --->
		<cfif qoq_img.recordcount NEQ 0>
			<!--- Add to Lucene --->
			<cfset _addImgToLucene(qoq = qoq_img) />
		</cfif>
		<!--- Video --->
		<cfif qoq_vid.recordcount NEQ 0>
			<!--- Add to Lucene --->
			<cfset _addVidToLucene(qoq = qoq_vid) />
		</cfif>
		<!--- Files --->
		<cfif qoq_doc.recordcount NEQ 0>
			<!--- Add to Lucene --->
			<cfset _addDocToLucene(qoq = qoq_doc) />
		</cfif>
		<!--- Audios --->
		<cfif qoq_aud.recordcount NEQ 0>
			<!--- Add to Lucene --->
			<cfset _addAudToLucene(qoq = qoq_aud) />
		</cfif>

	</cffunction>

	<!--- Get Images --->
	<cffunction name="_getImages" access="private" output="false">
		<cfargument name="hostid" required="true" type="string">
		<cfargument name="prefix" required="true" type="string">
		<cfargument name="file_id" required="true" type="string">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Getting Image: #arguments.file_id# for host: #arguments.hostid#")>
		<!--- Param --->
		<cfset var qry = "" >
		<!--- Get cache --->
		<cfset var cache = _getcachetoken("images", arguments.hostid) />
		<!--- Query Record --->
		<cfquery name="qry" datasource="#application.razuna.datasource#" cachedwithin="1" region="razcache">
		SELECT /* #cache#_getImages */ DISTINCT f.host_id collection, f.img_id id, f.folder_id_r folder, f.img_filename filename, f.img_filename_org filenameorg, f.link_kind, f.lucene_key,
		ct.img_description description, ct.img_keywords keywords, 
		f.img_extension theext, img_meta as rawmetadata, 'img' as category,
		x.subjectcode, x.creator, x.title, x.authorsposition, x.captionwriter, x.ciadrextadr, x.category as xmp_category,
		x.supplementalcategories, x.urgency, x.ciadrcity, 
		x.ciadrctry, x.location, x.ciadrpcode, x.ciemailwork, x.ciurlwork, x.citelwork, x.intellectualgenre, x.instructions, x.source,
		x.usageterms, x.copyrightstatus, x.transmissionreference, x.webstatement, x.headline, x.datecreated, x.city, x.ciadrregion, 
		x.country, x.countrycode, x.scene, x.state, x.credit, x.rights
		FROM #arguments.prefix#images f 
		LEFT JOIN #arguments.prefix#images_text ct ON f.img_id = ct.img_id_r
		LEFT JOIN #arguments.prefix#xmp x ON f.img_id = x.id_r AND x.asset_type = <cfqueryparam cfsqltype="cf_sql_varchar" value="img"> AND x.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.hostid#">
		WHERE f.img_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.file_id#">
		AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.hostid#">
		</cfquery>
		<!--- Return --->
		<cfreturn qry />
	</cffunction>

	<!--- Get File --->
	<cffunction name="_getDocs" access="private" output="false">
		<cfargument name="hostid" required="true" type="string">
		<cfargument name="prefix" required="true" type="string">
		<cfargument name="file_id" required="true" type="string">
		<cfargument name="notfile" required="true" type="string">
		<cfargument name="storage" required="true" type="string">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Getting Document: #arguments.file_id# for host: #arguments.hostid#")>
		<!--- Param --->
		<cfset var qry = "" >
		<!--- Get cache --->
		<cfset var cache = _getcachetoken("files", arguments.hostid) />
		<!--- Param --->
		<cfset var the_file = "">
		<!--- Query Record --->
		<cfquery name="qry" datasource="#application.razuna.datasource#" cachedwithin="1" region="razcache">
	    SELECT /* #cache#_getDocs */ DISTINCT f.host_id collection, f.file_id id, f.folder_id_r folder, f.file_name filename, f.file_name_org filenameorg, f.link_kind, f.lucene_key,
	    ct.file_desc description, ct.file_keywords keywords, 'doc' as category, f.file_meta as rawmetadata, 'doc' as thecategory, f.file_extension theext,
	    x.author, x.rights, x.authorsposition, x.captionwriter, x.webstatement, x.rightsmarked, '0' as thekey
		FROM #arguments.prefix#files f 
		LEFT JOIN #arguments.prefix#files_desc ct ON f.file_id = ct.file_id_r
		LEFT JOIN #arguments.prefix#files_xmp x ON f.file_id = x.asset_id_r AND x.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.hostid#">
		WHERE f.file_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.file_id#">
		AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.hostid#">
		</cfquery>
		<!--- Index only doc files --->
		<cfif qry.link_kind NEQ "url" AND arguments.notfile EQ "F">
			<cftry>
				<!--- Get assetpath of each host (could be different) --->
				<cfset var assetPath = getAssetPath(arguments.hostid, arguments.prefix) />
				<!--- Nirvanix or Amazon --->
				<cfif (arguments.storage EQ "amazon" OR arguments.storage EQ "akamai")>
					<!--- Check if windows or not --->
					<cfif ! _isWindows()>
						<cfset qry.lucene_key = replacenocase(qry.lucene_key," ","\ ","all")>
						<cfset qry.lucene_key = replacenocase(qry.lucene_key,"&","\&","all")>
						<cfset qry.lucene_key = replacenocase(qry.lucene_key,"'","\'","all")>
					</cfif>
					<!--- Index: Update file --->
					<cfif fileExists(qry.lucene_key)>
						<cfset var the_file = qry.lucene_key>
					</cfif>
				<!--- Local Storage --->
				<cfelseif qry.link_kind NEQ "lan" AND arguments.storage EQ "local" AND fileexists("#assetpath#/#arguments.hostid#/#qry.folder#/#qry.category#/#qry.id#/#qry.filenameorg#")>
					<!--- Index: Update file --->
					<cfset var the_file = "#assetpath#/#arguments.hostid#/#qry.folder#/#qry.category#/#qry.id#/#qry.filenameorg#">
				<!--- Linked file --->
				<cfelseif qry.link_kind EQ "lan">
					<cfset var qryfile ="">
					<cfquery name="qryfile" datasource="#application.razuna.datasource#">
						select link_path_url from #arguments.prefix#files where file_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.file_id#">
					</cfquery>
					<cfif fileexists("#qryfile.link_path_url#")>
						<!--- Index: Update file --->
						<cfset var the_file = qryfile.link_path_url>
					</cfif>
				</cfif>
				<cfcatch type="any">
					<cfset consoleoutput(true)>
					<cfset console("#now()# ---------------------- Error while indexing doc file #arguments.file_id#")>
					<cfset console(cfcatch)>
				</cfcatch>
			</cftry>
		</cfif>
		<!--- Decide on the key --->
		<cfif the_file EQ "">
			<cfset var thekey = qry.id>
		<cfelse>
			<cfset var thekey = the_file>
		</cfif>
		<!--- Set key properly --->
		<cfset QuerySetcell( qry, "thekey", thekey ) />
		<!--- Return --->
		<cfreturn qry />
	</cffunction>

	<!--- Get Videos --->
	<cffunction name="_getVideos" access="private" output="false">
		<cfargument name="hostid" required="true" type="string">
		<cfargument name="prefix" required="true" type="string">
		<cfargument name="file_id" required="true" type="string">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Getting Video: #arguments.file_id# for host: #arguments.hostid#")>
		<!--- Param --->
		<cfset var qry = "" >
		<!--- Get cache --->
		<cfset var cache = _getcachetoken("videos", arguments.hostid) />
		<!--- Query Record --->
		<cfquery name="qry" datasource="#application.razuna.datasource#" cachedwithin="1" region="razcache">
	    SELECT /* #cache#_getVideos */ DISTINCT f.host_id collection, f.vid_id id, f.folder_id_r folder, f.vid_filename filename, f.vid_name_org filenameorg, f.link_kind, f.lucene_key,
	    ct.vid_description description, ct.vid_keywords keywords, vid_meta as rawmetadata, 'vid' as thecategory, f.vid_extension theext, 'vid' as category
		FROM #arguments.prefix#videos f 
		LEFT JOIN #arguments.prefix#videos_text ct ON f.vid_id = ct.vid_id_r
		WHERE f.vid_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.file_id#">
		AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.hostid#">
		</cfquery>
		<!--- Return --->
		<cfreturn qry />
	</cffunction>

	<!--- Get Audios --->
	<cffunction name="_getAudios" access="private" output="false">
		<cfargument name="hostid" required="true" type="string">
		<cfargument name="prefix" required="true" type="string">
		<cfargument name="file_id" required="true" type="string">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Getting Audio: #arguments.file_id# for host: #arguments.hostid#")>
		<!--- Param --->
		<cfset var qry = "" >
		<!--- Get cache --->
		<cfset var cache = _getcachetoken("audios", arguments.hostid) />
		<!--- Query Record --->
		<cfquery name="qry" datasource="#application.razuna.datasource#" cachedwithin="1" region="razcache">
		SELECT /* #cache#_getAudios */ DISTINCT a.host_id collection, a.aud_id id, a.folder_id_r folder, a.aud_name filename, a.aud_name_org filenameorg, a.link_kind, a.lucene_key,
		aut.aud_description description, aut.aud_keywords keywords, a.aud_meta as rawmetadata, 'aud' as thecategory, a.aud_extension theext, 'aud' as category
		FROM #arguments.prefix#audios a
		LEFT JOIN #arguments.prefix#audios_text aut ON a.aud_id = aut.aud_id_r
		WHERE a.aud_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.file_id#">
		AND a.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.hostid#">
		</cfquery>
		<!--- Return --->
		<cfreturn qry />
	</cffunction>

	<!--- Get folder path --->
	<cffunction name="_folderPath" access="private" output="false">
		<cfargument name="hostid" required="true" type="string">
		<cfargument name="prefix" required="true" type="string">
		<cfargument name="folder" required="true" type="string">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Getting FolderPath: #arguments.folder# for host: #arguments.hostid#")>
		<!--- Param --->
		<cfset var folderpath = "" >
		<!--- Get folder path --->
		<cfset var qry_bc = _getbreadcrumb(folder_id_r = arguments.folder, prefix = arguments.prefix, hostid = arguments.hostid ) />
		<cfloop list="#qry_bc#" delimiters=";" index="p">
			<cfset folderpath = folderpath & "/" & listFirst(p, "|")>
		</cfloop>
		<!--- Return --->
		<cfreturn folderpath />
	</cffunction>

	<!--- Get Custom Fields --->
	<cffunction name="_getCustomFields" access="private" output="false">
		<cfargument name="hostid" required="true" type="string">
		<cfargument name="prefix" required="true" type="string">
		<cfargument name="file_id" required="true" type="string">
		<cfargument name="thedatabase" required="true" type="string">
		<cfargument name="category" required="true" type="string">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Getting Custom Fields: #arguments.file_id# (#arguments.category#) for host: #arguments.hostid#")>
		<!--- Param --->
		<cfset var qry = "" >
		<!--- Get cache --->
		<cfset var cache = _getcachetoken(arguments.category, arguments.hostid) />
		<!--- Query Record --->
		<cfquery name="qry" datasource="#application.razuna.datasource#" cachedwithin="1" region="razcache">
		SELECT /* #cache#_getCustomFields_#arguments.category# */ DISTINCT <cfif arguments.thedatabase EQ "mssql">cast(ft.cf_id_r AS VARCHAR(100)) + ' ' + cast(v.cf_value AS NVARCHAR(max))<cfelse>CONCAT(cast(ft.cf_id_r AS CHAR),' ',cast(v.cf_value AS CHAR))</cfif> AS customfieldvalue
		FROM #arguments.prefix#custom_fields_values v, #arguments.prefix#custom_fields_text ft
		WHERE v.asset_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.file_id#">
		AND v.cf_value != ''
		AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.hostid#">
		AND v.cf_id_r = ft.cf_id_r 
		AND v.host_id = ft.host_id 
		AND ft.lang_id_r = 1
		</cfquery>
		<!--- Add custom fields to a list --->
		<cfset var list = valuelist(qry.customfieldvalue, " ")>
		<!--- Return --->
		<cfreturn list />
	</cffunction>

	<!--- Get Labels --->
	<cffunction name="_getLabels" access="private" output="false">
		<cfargument name="hostid" required="true" type="string">
		<cfargument name="prefix" required="true" type="string">
		<cfargument name="file_id" required="true" type="string">
		<cfargument name="category" required="true" type="string">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Getting Labels: #arguments.file_id# (#arguments.category#) for host: #arguments.hostid#")>
		<!--- Param --->
		<cfset var qry = "" >
		<!--- Get cache --->
		<cfset var cache = _getcachetoken(arguments.category, arguments.hostid) />
		<!--- Query Record --->
		<cfquery name="qry" datasource="#application.razuna.datasource#" cachedwithin="1" region="razcache">
		SELECT /* #cache#_getLabels */ DISTINCT l.label_path
		FROM ct_labels ct, #arguments.prefix#labels l
		WHERE ct.ct_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.file_id#">
		AND l.label_id = ct.ct_label_id
		AND l.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.hostid#">
		</cfquery>
		<!--- if records found --->
		<cfif qry.recordcount NEQ 0>
			<!--- Add labels to a list --->
			<cfset var list = valuelist(qry.label_path," ")>
			<cfset var list = replace(list,"/"," ","all")>
		<cfelse>
			<cfset var list = "" />
		</cfif>
		<!--- Return --->
		<cfreturn list />
	</cffunction>

	<!--- Add to Lucene --->
	<cffunction name="_addImgToLucene" access="private" output="false">
		<cfargument name="qoq" required="true" type="query">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Adding #qoq.recordcount# to Image Index")>
		<!--- Param --->
		<cfset var qry_records = "">
		<!--- Indexing --->
		<cfset var _hosts = ListRemoveDuplicates(valuelist(arguments.qoq.collection)) />
		<!--- Loop over hosts --->
		<cfloop list="#_hosts#" delimiters="," index="h">
			<!--- Get all records of this host --->
			<cfquery dbtype="query" name="qry_records">
			SELECT *
			FROM arguments.qoq
			WHERE collection = #h#
			</cfquery>
			<cftry>
				<cfscript>
					args = {
					query : qry_records,
					collection : h,
					category : "category",
					categoryTree : "id",
					key : "id",
					title : "id",
					body : "id",
					custommap :{
						id : "id",
						filename : "filename",
						filenameorg : "filenameorg",
						keywords : "keywords",
						description : "description",
						rawmetadata : "rawmetadata",
						extension : "theext",
						subjectcode : "subjectcode",
						creator : "creator",
						title : "title", 
						authorsposition : "authorsposition", 
						captionwriter : "captionwriter", 
						ciadrextadr : "ciadrextadr", 
						category : "xmp_category",
						supplementalcategories : "supplementalcategories", 
						urgency : "urgency",
						ciadrcity : "ciadrcity", 
						ciadrctry : "ciadrctry", 
						location : "location", 
						ciadrpcode : "ciadrpcode", 
						ciemailwork : "ciemailwork", 
						ciurlwork : "ciurlwork", 
						citelwork : "citelwork", 
						intellectualgenre : "intellectualgenre", 
						instructions : "instructions", 
						source : "source",
						usageterms : "usageterms", 
						copyrightstatus : "copyrightstatus", 
						transmissionreference : "transmissionreference", 
						webstatement : "webstatement", 
						headline : "headline", 
						datecreated : "datecreated", 
						city : "city", 
						ciadrregion : "ciadrregion", 
						country : "country", 
						countrycode : "countrycode", 
						scene : "scene", 
						state : "state", 
						credit : "credit", 
						rights : "rights",
						labels : "labels",
						customfieldvalue : "customfieldvalue",
						folderpath : "folderpath",
						folder : "folder",
						host_id : "host_id"
						}
					};
					results = CollectionIndexCustom( argumentCollection=args );
				</cfscript>
				<cfcatch type="any">
					<cfset console(cfcatch) />
				</cfcatch>
			</cftry>
		</cfloop>
		<!--- Param --->
		<cfset var qry_records = "">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Finished adding #qoq.recordcount# to Image Index")>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- Add to Lucene --->
	<cffunction name="_addDocToLucene" access="private" output="false">
		<cfargument name="qoq" required="true" type="query">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Adding #qoq.recordcount# to Document Index")>
		<!--- Param --->
		<cfset var qry_records = "">
		<!--- Indexing --->
		<cfset var _hosts = ListRemoveDuplicates(valuelist(arguments.qoq.collection)) />
		<!--- Loop over hosts --->
		<cfloop list="#_hosts#" delimiters="," index="h">
			<!--- Get all records of this host --->
			<cfquery dbtype="query" name="qry_records">
			SELECT *
			FROM arguments.qoq
			WHERE collection = #h#
			</cfquery>
			<!--- Indexing --->
			<cftry>
				<cfscript>
					args = {
					query : qry_records,
					collection : h,
					category : "category",
					categoryTree : "id",
					key : "thekey",
					title : "id",
					body : "id",
					custommap :{
						id : "id",
						filename : "filename",
						filenameorg : "filenameorg",
						keywords : "keywords",
						description : "description",
						rawmetadata : "rawmetadata",
						extension : "theext",
						author : "author",
						rights : "rights",
						authorsposition : "authorsposition", 
						captionwriter : "captionwriter", 
						webstatement : "webstatement", 
						rightsmarked : "rightsmarked",
						labels : "labels",
						customfieldvalue : "customfieldvalue",
						folderpath : "folderpath",
						folder : "folder",
						host_id : "host_id"
						}
					};
					results = CollectionIndexfile( argumentCollection=args );
				</cfscript>
				<cfcatch type="any">
					<cfset console("#now()# ---------------------- ERROR")>
					<cfset console(cfcatch)>
				</cfcatch>
			</cftry>
		</cfloop>
		<!--- Param --->
		<cfset var qry_records = "">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Finished adding #qoq.recordcount# to Document Index")>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- Add to Lucene --->
	<cffunction name="_addVidToLucene" access="private" output="false">
		<cfargument name="qoq" required="true" type="query">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Adding #qoq.recordcount# to Video Index")>
		<!--- Param --->
		<cfset var qry_records = "">
		<!--- Indexing --->
		<cfset var _hosts = ListRemoveDuplicates(valuelist(arguments.qoq.collection)) />
		<!--- Loop over hosts --->
		<cfloop list="#_hosts#" delimiters="," index="h">
			<!--- Get all records of this host --->
			<cfquery dbtype="query" name="qry_records">
			SELECT *
			FROM arguments.qoq
			WHERE collection = #h#
			</cfquery>
			<!--- Indexing --->
			<cfscript>
				args = {
				query : qry_records,
				collection : h,
				category : "category",
				categoryTree : "id",
				key : "id",
				title : "id",
				body : "id",
				custommap :{
					id : "id",
					filename : "filename",
					filenameorg : "filenameorg",
					keywords : "keywords",
					description : "description",
					rawmetadata : "rawmetadata",
					extension : "theext",
					labels : "labels",
					customfieldvalue : "customfieldvalue",
					folderpath : "folderpath",
					folder : "folder",
					host_id : "host_id"
					}
				};
				results = CollectionIndexCustom( argumentCollection=args );
			</cfscript>
		</cfloop>
		<!--- Param --->
		<cfset var qry_records = "">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Finished adding #qoq.recordcount# to Video Index")>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- Add to Lucene --->
	<cffunction name="_addAudToLucene" access="private" output="false">
		<cfargument name="qoq" required="true" type="query">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Adding #qoq.recordcount# to Audio Index")>
		<!--- Param --->
		<cfset var qry_records = "">
		<!--- Indexing --->
		<cfset var _hosts = ListRemoveDuplicates(valuelist(arguments.qoq.collection)) />
		<!--- Loop over hosts --->
		<cfloop list="#_hosts#" delimiters="," index="h">
			<!--- Get all records of this host --->
			<cfquery dbtype="query" name="qry_records">
			SELECT *
			FROM arguments.qoq
			WHERE collection = #h#
			</cfquery>
			<!--- Indexing --->
			<cfscript>
				args = {
				query : qry_records,
				collection : h,
				category : "category",
				categoryTree : "id",
				key : "id",
				title : "id",
				body : "id",
				custommap :{
					id : "id",
					filename : "filename",
					filenameorg : "filenameorg",
					keywords : "keywords",
					description : "description",
					rawmetadata : "rawmetadata",
					extension : "theext",
					labels : "labels",
					customfieldvalue : "customfieldvalue",
					folderpath : "folderpath",
					folder : "folder",
					host_id : "host_id"
					}
				};
				results = CollectionIndexCustom( argumentCollection=args );
			</cfscript>
		</cfloop>
		<!--- Param --->
		<cfset var qry_records = "">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Finished adding #qoq.recordcount# to Audio Index")>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- Update DB --->
	<cffunction name="_updateDb" access="private" output="false">
		<cfargument name="qryfiles" required="true" type="query">
		<!--- Loop over qoq --->
		<cfloop query="arguments.qryfiles">
			<cfif category EQ "img">
				<cfset var db = "images" />
				<cfset var theid = "img_id" />
			<cfelseif category EQ "vid">
				<cfset var db = "videos" />
				<cfset var theid = "vid_id" />
			<cfelseif category EQ "aud">
				<cfset var db = "audios" />
				<cfset var theid = "aud_id" />
			<cfelseif category EQ "doc">
				<cfset var db = "files" />
				<cfset var theid = "file_id" />
			</cfif>
			<!--- Log --->
			<cfset console("#now()# ---------------------- Updating #file_id# (#db#) record for Host #host_id#")>
			<!--- Update database --->
			<cfquery datasource="#application.razuna.datasource#">
			UPDATE #prefix##db#
			SET is_indexed = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="1">
			WHERE #theid# = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#file_id#">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#host_id#">
			</cfquery>
		</cfloop>
		<!--- Group hosts --->
		<cfset var _hosts = ListRemoveDuplicates(valuelist(arguments.qryfiles.host_id)) />
		<!--- Loop over hosts --->
		<cfloop list="#_hosts#" delimiters="," index="host_id">
		<!--- Flush cache for this host --->
			<cfset _resetcachetoken(type="search", hostid=host_id) />
			<cfset _resetcachetoken(type="images", hostid=host_id) />
			<cfset _resetcachetoken(type="videos", hostid=host_id) />
			<cfset _resetcachetoken(type="files", hostid=host_id) />
			<cfset _resetcachetoken(type="audios", hostid=host_id) />
		</cfloop>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- Query records to remove --->
	<cffunction name="_qryRemoveRecords" access="private" output="false" returntype="query">
		<cftry>
			<!--- Log --->
			<cfset console("#now()# ---------------------- Fetching records to remove from index")>
			<!--- Param --->
			<cfset var qry = "">
			<!--- Query --->
			<cfquery datasource="#application.razuna.datasource#" name="qry">
			SELECT id, type, host_id
			FROM lucene
			</cfquery>
			<!--- Only continue if records are found --->
			<cfif qry.recordcount NEQ 0>
				<!--- Log --->
				<cfset console("#now()# ---------------------- Found #qry.recordcount# records to remove")>
			<cfelse>
				<!--- Log --->
				<cfset console("#now()# ---------------------- Found #qry.recordcount# records to remove. Aborting...")>
				<cfabort>
			</cfif>
			<!--- Return --->
			<cfreturn qry />
			<cfcatch type="any">
				<cfset consoleoutput(true)>
				<cfset console("#now()# ---------------------- Error fetching records. Aborting... !!!!!!!!!!!!!!!!!!!!!!!!!")>
				<cfset console(cfcatch)>
				<cfabort>
			</cfcatch>
		</cftry>
	</cffunction>

	<!--- Query records to remove --->
	<cffunction name="_removeFromIndex" access="private" output="false">
		<cfargument name="qryrecords" required="true" type="query">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Removing #qryrecords.recordcount# records from index")>
		<!--- Group hosts --->
		<cfset var _hosts = ListRemoveDuplicates(valuelist(arguments.qryrecords.host_id)) />
		<!--- Loop over hosts --->
		<cfloop list="#_hosts#" delimiters="," index="host_id">
		<!--- Simple remove records in Lucene. Id is the key --->
			<cfscript>
				args = {
					query : arguments.qryrecords,
					collection : "#host_id#",
					key : "id"
				};
				results = CollectionIndexdelete( argumentCollection=args );
			</cfscript>
		</cfloop>
		<!--- Log --->
		<cfset console("#now()# ---------------------- Finished removing #qryrecords.recordcount# records from index")>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- Remove in DB --->
	<cffunction name="_removeFromDatabase" access="private" output="false">
		<cfargument name="qryrecords" required="true" type="query">
		<!--- Log --->
		<cfset console("#now()# ---------------------- Removing #qryrecords.recordcount# records in database")>
		<!--- Delete --->
		<cfloop query="arguments.qryrecords">
			<cfquery datasource="#application.razuna.datasource#">
			DELETE FROM lucene
			WHERE id = <cfqueryparam value="#id#" cfsqltype="cf_sql_varchar">
			</cfquery>
		</cfloop>
		<!--- Log --->
		<cfset console("#now()# ---------------------- All #qryrecords.recordcount# records removed in database")>
		<!--- Return --->
		<cfreturn />
	</cffunction>

</cfcomponent>
