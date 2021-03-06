<cfcomponent>

	<!--- These are called from the cron jobs --->

	<!--- Run indexing --->
	<cffunction name="index" output="false" access="public">
		<!--- Log --->
		<cfif application.razuna.debug>
			<cfset console("#now()# --- Executing Indexing from Cron")>
		</cfif>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="indexFiles" />
		<cfreturn />
	</cffunction>

	<!--- Run Deleting --->
	<cffunction name="remove" output="false" access="public">
		<!--- Log --->
		<cfif application.razuna.debug>
			<cfset console("#now()# --- Executing Remove from Cron")>
		</cfif>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="removeFiles" />
		<cfreturn />
	</cffunction>

	<!--- Run Update --->
	<cffunction name="update" output="false" access="public">
		<!--- Log --->
		<cfif application.razuna.debug>
			<cfset console("#now()# --- Executing Update from Cron")>
		</cfif>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="updateIndex" />
		<cfreturn />
	</cffunction>

	<!--- Run Update Lucene --->
	<cffunction name="updateLucene" output="false" access="public">
		<!--- Log --->
		<cfif application.razuna.debug>
			<cfset console("#now()# --- Executing Update Lucene from Cron")>
		</cfif>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="updateLucene" />
		<cfreturn />
	</cffunction>

	<!--- Integrity Check --->
	<cffunction name="integrityCheck" output="false" access="public">
		<!--- Log --->
		<cfif application.razuna.debug>
			<cfset console("#now()# --- Executing integrity check from Cron")>
		</cfif>
		<!--- Call Indexing --->
		<cfinvoke component="indexing" method="integrityCheck" />
		<cfreturn />
	</cffunction>

</cfcomponent>
