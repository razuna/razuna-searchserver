<cfcomponent>

  <cffunction name="onServerStart">
    <cfset consoleoutput(true, true)>
    <cfset console("------------SEARCHSERVER: SERVER STARTUP------------------")>
    <!--- Delete any .lock file --->
    <cftry>
      <cfset console("---SEARCHSERVER: START: Lock file cleanup---")>
      <cfdirectory action="list" directory="#GetTempdirectory()#" listinfo="name" filter="*.lock" name="l">
      <cfif l.recordcount NEQ 0>
        <cfloop query="l">
          <cfset filedelete(GetTempdirectory() & name)>
        </cfloop>
        <cfset console("SEARCHSERVER: All .lock files have been deleted")>
      <cfelse>
        <cfset console("SEARCHSERVER: No .lock file to remove")>
      </cfif>
      <cfset console("---SEARCHSERVER: DONE: Lock file cleanup---")>
      <cfcatch type="any">
        <cfset console("SEARCHSERVER: Lock removal error #cfcatch#")>
      </cfcatch>
    </cftry>

    <cftry>
      <cfset console("------------SEARCHSERVER: ENABLING CRON------------------")>
      <cfset cronEnable(true) />
      <cfcatch type="any">
        <cfset console("------------ SEARCHSERVER: Cron error !!!!!!!!!!!!!!!!!!!!!!!!!")>
        <cfset console(cfcatch)>
      </cfcatch>
    </cftry>
    <cftry>
      <cfset console("------------SEARCHSERVER: ENABLING CRON DIRECTORY------------------")>
       <cfset CronSetDirectory("/cron") />
      <cfcatch type="any">
        <cfset console("------------ SEARCHSERVER: Cron error !!!!!!!!!!!!!!!!!!!!!!!!!")>
        <cfset console(cfcatch)>
      </cfcatch>
    </cftry>
    <cfset console("---------------SEARCHSERVER: FINISHED---------------------")>
    <cfset consoleoutput(false, false)>
  </cffunction>

</cfcomponent>