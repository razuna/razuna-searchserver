<cfcomponent>

	<!--- Run indexing --->
	<cffunction name="index" output="false" access="public">
		<!--- Log --->
		<cfset consoleoutput(true)>
		<cfset console("#now()# --- Executing Indexing from Cron")>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="indexFiles" />
	</cffunction>

	<!--- Run Deleting --->
	<cffunction name="remove" output="false" access="public">
		<!--- Log --->
		<cfset consoleoutput(true)>
		<cfset console("#now()# --- Executing Remove from Cron")>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="removeFiles" />
	</cffunction>

</cfcomponent>






