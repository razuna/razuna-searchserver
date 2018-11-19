<cfcomponent>

	<!--- These are called from the cron jobs --->

	<!--- Run indexing --->
	<cffunction name="index" output="false" access="public">
		<!--- Log --->
		<cfif debug>
			<cfset console("#now()# --- Executing Indexing from Cron")>
		</cfif>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="indexFiles" />
		<cfreturn />
	</cffunction>

	<!--- Run Deleting --->
	<cffunction name="remove" output="false" access="public">
		<!--- Log --->
		<cfif debug>
			<cfset console("#now()# --- Executing Remove from Cron")>
		</cfif>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="removeFiles" />
		<cfreturn />
	</cffunction>

	<!--- Run Update --->
	<cffunction name="update" output="false" access="public">
		<!--- Log --->
		<cfif debug>
			<cfset console("#now()# --- Executing Update from Cron")>
		</cfif>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="updateIndex" />
		<cfreturn />
	</cffunction>

</cfcomponent>
