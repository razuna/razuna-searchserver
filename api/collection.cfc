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
	<cffunction name="createCollections" access="public" output="false">
		<!--- Log --->
		<cfset consoleoutput(true)>
		<cfset console("#now()# ---------------------- Creating new collections")>
		<!--- Grab all hosts --->
		<cfset var _qry_hosts = _qryHosts()>
		<!--- Loop over hosts --->
		<cfloop query="_qry_hosts">
			<!---Create Collection --->
			<cftry>
				<!--- Create --->
				<cfset CollectionCreate(collection=host_id, relative=true, path="/WEB-INF/collections/#host_id#")>
				<cfset console("#now()# ---------------------- Setting up collection for Host #host_id#")>
				<cfcatch type="any">
				<cfset console("#now()# ---------------------- Collection for Host #host_id# already exists")>
				</cfcatch>
			</cftry>
		</cfloop>
		<!--- Return --->
		<cfreturn />
	</cffunction>

	<!--- PRIVATE --->

</cfcomponent>




