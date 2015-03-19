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

	<!--- Create search collection --->
	<cffunction name="createCollection" access="remote" output="false" returnformat="json">
		<cfargument name="collection" required="true" type="string">
		<cfargument name="secret" required="true" type="string">
		<!--- Check login --->
		<cfset auth(arguments.secret)>
		<!--- Param --->
		<cfset r.success = true>
		<cfset r.error = "">
		<!--- Call internal function --->
		<cfinvoke method="_createCollection" collection="#arguments.collection#">
		<!--- Return --->
		<cfreturn r />
	</cffunction>

	<!--- Delete search collection --->
	<cffunction name="removeCollection" access="remote" output="false" returnformat="json">
		<cfargument name="collection" required="true" type="string">
		<cfargument name="secret" required="true" type="string">
		<!--- Check login --->
		<cfset auth(arguments.secret)>
		<!--- Param --->
		<cfset r.success = true>
		<cfset r.error = "">
		<!--- Delete collection --->
		<cftry>
			<cfset CollectionDelete(arguments.collection)>
			<cfcatch type="any">
				<cfset r.success = false>
				<cfset r.error = cfcatch.message>
			</cfcatch>
		</cftry>
		<!--- Return --->
		<cfreturn r />
	</cffunction>
	
	<!--- Check for Collection --->
	<cffunction name="checkCollection" access="public" output="false">
		<cfargument name="collection" required="true" type="string">
		<cftry>
			<!--- Log --->
			<cfset console("#now()# ---------------------- Checking that collection exists for Host #arguments.collection#")>
			<!--- Get the collection --->
			<cfset CollectionStatus(arguments.collection)>
			<!--- Collection does NOT exists, thus create it --->
			<cfcatch>
		    	<cfinvoke method="_createCollection" collection="#arguments.collection#">
			</cfcatch>
		</cftry>
		<!--- Return --->
		<cfreturn />
	</cffunction>


	<!--- PRIVATE --->


	

	<!--- Check for Collection --->
	<cffunction name="_createCollection" access="private" output="false">
		<cfargument name="collection" required="true" type="string">
		<!--- Delete collection --->
		<cftry>
			<cfset CollectionDelete(arguments.collection)>
			<cfcatch type="any"></cfcatch>
		</cftry>
		<!--- Delete path on disk --->
		<cftry>
			<cfset var d = REReplaceNoCase(GetTempDirectory(),"/bluedragon/work/temp","","one")>
			<cfdirectory action="delete" directory="#d#collections/#arguments.collection#" recurse="true" />
			<cfcatch type="any"></cfcatch>
		</cftry>
		<!--- Create collection --->
		<cftry>
			<!--- Log --->
			<cfset console("#now()# ---------------------- Creating collection for Host #arguments.collection#")>
			<!--- Create --->
			<cfset CollectionCreate(collection=arguments.collection,relative=true,path="/WEB-INF/collections/#arguments.collection#")>
			<cfcatch type="any">
				<cfset r.success = false>
				<cfset r.error = cfcatch.message>
			</cfcatch>
		</cftry>
		<!--- Return --->
		<cfreturn />
	</cffunction>

</cfcomponent>




