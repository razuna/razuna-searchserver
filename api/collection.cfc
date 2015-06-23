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

	<!--- REMOTE --->

	<!--- Rebuild Collection --->
	<cffunction name="rebuildCollection" access="remote" output="false">
		<cfargument name="hostid" required="true" type="string">
		<cfargument name="secret" required="true" type="string">
		<!--- Log --->
		<cfset consoleoutput(true)>
		<cfset console("#now()# ---------------------- Removing Collection for rebuild")>
		<!--- Check login --->
		<cfset auth(arguments.secret)>
		<!--- Remove Collection --->
		<cftry>
			<cfset CollectionDelete(arguments.hostid)>
			<cfset console("#now()# ---------------------- Collection removed for rebuild")>
			<cfpause interval="10" />
			<cfcatch type="any"></cfcatch>
		</cftry>
		<!--- Now create it again --->
		<cftry>
			<cfset console("#now()# ---------------------- CREATING collection for Host #arguments.hostid#")>
			<!--- Create --->
			<cfset CollectionCreate(collection=arguments.hostid, relative=true, path="/WEB-INF/collections/#arguments.hostid#")>
			<cfset console("#now()# ---------------------- DONE creating collection for Host #arguments.hostid#")>
			<cfcatch type="any"></cfcatch>
		</cftry>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- This is being called from create collection cron job --->
	<cffunction name="createCollection" access="remote" output="false">
		<!--- Log --->
		<cfset consoleoutput(true)>
		<cfset console("#now()# ---------------------- Creating new collections")>
		<!--- Grab all hosts --->
		<cfset var _qry_hosts = _qryHosts()>
		<!--- Loop over hosts --->
		<cfloop query="_qry_hosts">
			<!---Create Collection --->
			<cftry>
				<cfset console("#now()# ---------------------- CREATING collection for Host #host_id#")>
				<!--- Create --->
				<cfset CollectionCreate(collection=host_id, relative=true, path="/WEB-INF/collections/#host_id#")>
				<cfset console("#now()# ---------------------- DONE creating collection for Host #host_id#")>
				<cfcatch type="any"></cfcatch>
			</cftry>
		</cfloop>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- PUBLIC --->

	<!--- Check for Collection --->
	<cffunction name="checkCollection" access="public" output="false">
		<cfargument name="hostid" required="true" type="string">
		<!--- Log --->
		<!--- <cfset console("#now()# ---------------------- Checking that collection exists for Host #arguments.hostid#")> --->
		<!--- We simply create a collection and let it throw an error --->
		<cftry>
			<!--- Log --->
			<!--- <cfset console("#now()# ---------------------- Checking for collection for Host #arguments.hostid#")> --->
			<cfset console("#now()# ---------------------- CREATING collection for Host #arguments.hostid#")>
			<!--- Create --->
			<cfset CollectionCreate(collection=arguments.hostid, relative=true, path="/WEB-INF/collections/#arguments.hostid#")>
			<!--- On error --->
			<cfcatch type="any">
				<!--- Log --->
				<cfset console("#now()# ---------------------- ERROR: Creating collection for Host #arguments.hostid#")>
				<cfset console("#now()# ---------------------- ERROR: #cfcatch.message#")>
			</cfcatch>
		</cftry>
		<cfreturn />
	</cffunction>


	<!--- PRIVATE --->


	

	<!--- Check for Collection --->
	<cffunction name="_createCollection" access="private" output="false">
		<cfargument name="hostid" required="true" type="string">
		<!--- Delete collection --->
		<cftry>
			<cfset CollectionDelete(arguments.hostid)>
			<cfcatch type="any"></cfcatch>
		</cftry>
		<!--- Delete path on disk --->
		<cftry>
			<cfset var d = REReplaceNoCase(GetTempDirectory(),"/bluedragon/work/temp","","one")>
			<cfdirectory action="delete" directory="#d#collections/#arguments.hostid#" recurse="true" />
			<cfcatch type="any"></cfcatch>
		</cftry>
		<!--- Create collection --->
		<cftry>
			<!--- Log --->
			<cfset console("#now()# ---------------------- Creating collection for Host #arguments.hostid#")>
			<!--- Create --->
			<cfset CollectionCreate(collection=arguments.hostid, relative=true, path="/WEB-INF/collections/#arguments.hostid#")>
			<!--- On error --->
			<cfcatch type="any">
				<cfset r.success = false>
				<cfset r.error = cfcatch.message>
			</cfcatch>
		</cftry>
		<!--- Return --->
		<cfreturn />
	</cffunction>

</cfcomponent>




