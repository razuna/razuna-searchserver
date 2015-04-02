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
* and conditions of version 3.0 of the AGPL as described in Razuna"s
* FLOSS exception. You should have received a copy of the FLOSS exception
* along with Razuna. If not, see <http://www.razuna.com/licenses/>.
*
--->
<cfcomponent output="false" extends="authentication">

	<!--- Create search collection --->
	<cffunction name="setup" access="remote" output="false" returntype="struct" returnformat="json">
		<cfargument name="db_type" required="true" type="string">
		<cfargument name="db_name" required="true" type="string">
		<cfargument name="db_server" required="true" type="string">
		<cfargument name="db_port" required="true" type="string">
		<cfargument name="db_schema" required="true" type="string">
		<cfargument name="db_user" required="true" type="string">
		<cfargument name="db_pass" required="true" type="string">
		<cfargument name="db_path" required="true" type="string">
		<!--- Log --->
		<cfset consoleoutput(true)>
		<cfset console("#now()# ---------------------- Adding DB connection")>
		<!--- Check login --->
		<!--- <cfset auth(arguments.secret)> --->
		<!--- Param --->
		<cfset r.success = true>
		<cfset r.error = "">
		<cfset r.results = "">
		<!--- Create the datasource --->
		<cfset var _result = _setdatasource(db_type=arguments.db_type, db_name=arguments.db_name, db_server=arguments.db_server, db_port=arguments.db_port, db_schema=arguments.db_schema, db_user=arguments.db_user, db_pass=arguments.db_pass, db_path=db_path)>
		<!--- If error --->
		<cfif !_result.success>
			<cfset r.success = false>
			<cfset r.error = _result.error>
		</cfif>
		<!--- Return --->
		<cfreturn r />
	</cffunction>



	<!--- PRIVATE --->




	<!--- Set datasource in bd_config --->
	<cffunction name="_setdatasource" access="private" output="false">
		<cfargument name="db_type" required="true" type="string">
		<cfargument name="db_name" required="true" type="string">
		<cfargument name="db_server" required="true" type="string">
		<cfargument name="db_port" required="true" type="string">
		<cfargument name="db_schema" required="true" type="string">
		<cfargument name="db_user" required="true" type="string">
		<cfargument name="db_pass" required="true" type="string">
		<cfargument name="db_path" required="true" type="string">
		<!--- Name of this connection --->
		<cfset var datasource_name = "razuna_datasource_name">
		<!--- Delete the current connection first --->
		<cftry>
			<cfinvoke component="bd_config" method="deleteDatasource">
				<cfinvokeargument name="dsn" value="#datasource_name#">
			</cfinvoke>
			<cfcatch type="any"></cfcatch>
		</cftry>
		<!--- Status --->
		<cfset var status = structNew()>
		<cfset status.success = true>
		<cfset status.error = "">
		<!--- Param --->
		<cfparam name="theconnectstring" default="">
		<cfparam name="hoststring" default="">
		<cfparam name="verificationQuery" default="">
		<!--- Set the correct drivername --->
		<cfif arguments.db_type EQ "h2">
			<cfset thedrivername = "org.h2.Driver">
			<cfset theconnectstring = "AUTO_RECONNECT=TRUE;AUTO_SERVER=TRUE">
		<cfelseif arguments.db_type EQ "mysql">
			<cfset thedrivername = "com.mysql.jdbc.Driver">
			<cfset theconnectstring = "zeroDateTimeBehavior=convertToNull">
		<cfelseif arguments.db_type EQ "mssql">
			<cfset thedrivername = "net.sourceforge.jtds.jdbc.Driver">
		</cfif>
		<!--- Log --->
		<cfset consoleoutput(true)>
		<cfset console("#now()# ---------------------- Inserting into config")>
		<!--- Set the datasource --->
		<cftry>
			<cfinvoke component="bd_config" method="setDatasource">
				<cfinvokeargument name="name" value="#datasource_name#">
				<cfinvokeargument name="databasename" value="#arguments.db_name#">
				<cfinvokeargument name="server" value="#arguments.db_server#">
				<cfinvokeargument name="port" value="#arguments.db_port#">
				<cfinvokeargument name="username" value="#arguments.db_user#">
				<cfinvokeargument name="password" value="#arguments.db_pass#">
				<cfinvokeargument name="action" value="create">
				<cfinvokeargument name="existingDatasourceName" value="#datasource_name#">
				<cfinvokeargument name="drivername" value="#thedrivername#">
				<cfinvokeargument name="h2Mode" value="Oracle">
				<cfinvokeargument name="connectstring" value="#theconnectstring#">
				<cfinvokeargument name="hoststring" value="#hoststring#">
				<cfinvokeargument name="verificationQuery" value="#verificationQuery#">
				<cfinvokeargument name="filepath" value="#arguments.db_path#">
			</cfinvoke>
			<cfcatch type="any">
				<cfset status.success = false>
				<cfset status.error = cfcatch>
			</cfcatch>
		</cftry>
		<!--- Return --->
		<cfreturn status />
	</cffunction>



</cfcomponent>
