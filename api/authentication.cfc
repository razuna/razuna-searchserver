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
<cfcomponent output="false">

	<!--- Path for this file --->
	<!--- If path contains cron we have to go up one more --->
	<cfif ExpandPath("../") CONTAINS "cron">
		<cfset this._path = ExpandPath("../../") />
	<cfelse>
		<cfset this._path = ExpandPath("../") />
	</cfif>
	

	<!--- Check for key --->
	<cffunction name="auth" access="public" output="false">
		<cfargument name="secret" type="string">
		<!--- Param --->
		<cfset var login = false />
		<!--- Get remote secret --->
		<cfset var _secret_remote = _getSecretRemote()>
		<!--- If passed and remote secret match --->
		<cfif arguments.secret EQ _secret_remote>
			<cfset var login = true />
		</cfif>
		<cfif !login>
			<!--- Log --->
			<cfset consoleoutput(true)>
			<cfset console("#now()# ---------------------- Secret key is not valid! Aborting...")>
			<cfabort>
		</cfif>
		<!--- Return --->
		<cfreturn login />
	</cffunction>

	<!--- Send no access --->
	<cffunction name="noAccess" access="public" output="false" returnformat="json">
		<cflocation url="/noaccess.cfm" />
	</cffunction>

	<!--- Check for key --->
	<cffunction name="getConfig" access="public" output="false">
		<cftry>
			<!--- Param --->
			<cfset var qry = "">
			<cfset var s = structNew()>
			<!--- Query --->
			<cfquery datasource="#application.razuna.datasource#" name="qry">
			SELECT opt_id, opt_value
			FROM options
			WHERE opt_id LIKE <cfqueryparam cfsqltype="cf_sql_varchar" value="conf_%">
			</cfquery>
			<!--- Get value --->
			<cfloop query="qry">
				<cfset s["#opt_id#"] = opt_value>
			</cfloop>
			<!--- Return --->
			<cfreturn s />
			<cfcatch type="any">
				<cfset consoleoutput(true)>
				<cfset console("#now()# ---------------------- Config Error. Aborting... !!!!!!!!!!!!!!!!!!!!!!!!!")>
				<cfset console(cfcatch)>
				<cfabort>
			</cfcatch>
   		</cftry>
		
	</cffunction>
	
	<!--- Get Cachetoken --->
	<cffunction name="getcachetoken" output="false" returntype="string">
		<cfargument name="type" type="string" required="yes">
		<cfargument name="hostid" type="string" required="yes">
		<!--- Call --->
		<cfset _getcachetoken(arguments.type, arguments.hostid)>
		<!--- Return --->
		<cfreturn c />
	</cffunction>

	<!--- reset the global caching variable of this cfc-object --->
	<cffunction name="resetcachetoken" output="false" returntype="void">
		<cfargument name="type" type="string" required="yes">
		<cfargument name="hostid" type="string" required="yes">
		<!--- Call --->
		<cfset _resetcachetoken(arguments.type, arguments.hostid)>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- Grab assetpath --->
	<cffunction name="getAssetPath" output="false" returntype="string">
		<cfargument name="hostid" type="string" required="yes">
		<cfargument name="prefix" type="string" required="yes">
		<!--- Get cachetoken --->
		<cfset cachetoken = _getcachetoken("settings", arguments.hostid)>
		<!--- Param --->
		<cfset var qry = "" />
		<!--- Query --->
		<cfquery datasource="#application.razuna.datasource#" name="qry" cachedwithin="1" region="razcache">
		SELECT /* #cachetoken#getAssetPath */ set2_path_to_assets
		FROM #arguments.prefix#settings_2
		WHERE host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.hostid#">
		</cfquery>
		<!--- Set path --->
		<cfset var assetpath = trim(qry.set2_path_to_assets)>
		<!--- Return --->
		<cfreturn assetpath />
	</cffunction>

	<!---  --->
	<!--- PRIVATE --->
	<!---  --->

	<cffunction name="_getcachetoken" access="private" output="false" returntype="string">
		<cfargument name="type" type="string" required="yes">
		<cfargument name="hostid" type="string" required="yes">
		<!--- Param --->
		<cfset var qry = queryNew("cache_token")>
		<!--- Query --->
		<cftry>
			<cfquery dataSource="#application.razuna.datasource#" name="qry">
			SELECT cache_token
			FROM cache
			WHERE host_id = <cfqueryparam value="#arguments.hostid#" CFSQLType="CF_SQL_NUMERIC">
			AND cache_type = <cfqueryparam value="#arguments.type#" CFSQLType="CF_SQL_VARCHAR">
			</cfquery>
			<cfcatch type="any">
				<cfset queryAddRow(qry, 1)>
				<cfset querySetCell(qry, "cache_token", createuuid(''))>
			</cfcatch>
		</cftry>
		<cfreturn qry.cache_token />
	</cffunction>

	<!--- reset the global caching variable of this cfc-object --->
	<cffunction name="_resetcachetoken" access="private" output="false" returntype="string">
		<cfargument name="type" type="string" required="yes">
		<cfargument name="hostid" type="string" required="yes">
		<cfargument name="nohost" type="string" required="false" default="false">
		<!--- Create token --->
		<cfset var t = createuuid('')>
		<!--- Update DB --->
		<cftry>
			<cfquery dataSource="#application.razuna.datasource#">
			UPDATE cache
			SET cache_token = <cfqueryparam value="#t#" CFSQLType="CF_SQL_VARCHAR">
			WHERE cache_type = <cfqueryparam value="#arguments.type#" CFSQLType="CF_SQL_VARCHAR">
			<cfif !arguments.nohost>
				AND host_id = <cfqueryparam value="#arguments.hostid#" CFSQLType="CF_SQL_NUMERIC">
			</cfif>
			</cfquery>
			<cfcatch type="database"></cfcatch>
		</cftry>
		<cfreturn t>
	</cffunction>

	<!--- Check for plattform --->
	<cffunction name="_isWindows" returntype="boolean" access="public" output="false">
		<!--- function body --->
		<cfreturn FindNoCase("Windows", server.os.name)>
	</cffunction>

	<!--- Get folder breadcrumb (backwards) --->
	<cffunction name="_getbreadcrumb" output="false">
		<cfargument name="folder_id_r" type="string" required="true">
		<cfargument name="prefix" type="string" required="true">
		<cfargument name="hostid" type="string" required="true">
		<cfargument name="folderlist" type="string" default="" required="false">
		<cftry>
			<!--- Params --->
			<cfset var qry = "">
			<cfset var flist = "">
			<!--- Get the cachetoken for here --->
			<cfset var cachetoken = _getcachetoken("folders", arguments.hostid)>
			<!--- Query: Get current folder_id_r --->
			<cfquery datasource="#application.razuna.datasource#" name="qry" cachedwithin="1" region="razcache">
			SELECT /* #cachetoken#getbreadcrumb */ f.folder_name, f.folder_id_r, f.folder_id
			FROM #arguments.prefix#folders f
			WHERE f.folder_id = <cfqueryparam value="#arguments.folder_id_r#" cfsqltype="CF_SQL_VARCHAR">
			AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.hostid#">
			</cfquery>
			<!--- No recursivness if no more records --->
			<cfif qry.recordcount NEQ 0>
				<!--- Set the current values into the list --->
				<cfset flist = qry.folder_name & "|" & qry.folder_id & "|" & qry.folder_id_r & ";" & arguments.folderlist>
				<!--- If the folder_id_r is not the same the passed one --->
				<cfif qry.folder_id_r NEQ arguments.folder_id_r>
					<!--- Call this function again (need component otherwise it won't work for internal calls) --->
					<cfinvoke method="_getbreadcrumb" folder_id_r="#qry.folder_id_r#" folderlist="#flist#" prefix="#arguments.prefix#" hostid="#arguments.hostid#" />
				</cfif>
			<cfelse>
				<!--- Set the current values into the list --->
				<cfset flist = arguments.folderlist>
			</cfif>
			<!--- Return --->	
			<cfreturn flist>
			<cfcatch type="any">
				<cfset consoleoutput(true)>
				<cfset console(cfcatch)>
			</cfcatch>
		</cftry>
	</cffunction>

	<!--- Get Remote key --->
	<cffunction name="_getSecretRemote" access="private" output="false" returntype="string">
		<!--- Query --->
		<cftry>
			<cfset consoleoutput(true)>
			<cfset console("#now()# ---------------------- Fetching remote secret key")>
			<!--- Param --->
			<cfset var qry = "">
			<cfset var key = "">
			<!--- Query --->
			<cfquery dataSource="#application.razuna.datasource#" name="qry">
			SELECT opt_value
			FROM options
			WHERE lower(opt_id) = <cfqueryparam value="taskserver_secret" CFSQLType="CF_SQL_VARCHAR">
			</cfquery>
			<cfset var key = trim(qry.opt_value)>
			<cfcatch type="any">
				<cfset console(cfcatch)>
				<cfset var key = "">
			</cfcatch>
		</cftry>
		<cfset console("#now()# ---------------------- Found key : #key#")>
		<cfreturn key />
	</cffunction>

</cfcomponent>




