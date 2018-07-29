<cfcomponent>

	<!--- These are called from the cron jobs --->

	<!--- Run indexing --->
	<cffunction name="index" output="false" access="public">
		<!--- Log --->
		<cfset console("#now()# --- Executing Indexing from Cron")>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="indexFiles" />
		<cfreturn />
	</cffunction>

	<!--- Run Deleting --->
	<cffunction name="remove" output="false" access="public">
		<!--- Log --->
		<cfset console("#now()# --- Executing Remove from Cron")>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="removeFiles" />
		<cfreturn />
	</cffunction>

	<!--- Run Update --->
	<cffunction name="update" output="false" access="public">
		<!--- Log --->
		<cfset console("#now()# --- Executing Update from Cron")>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="updateIndex" />
		<cfreturn />
	</cffunction>

</cfcomponent>
