<cfcomponent>

  <cffunction name="onServerStart">
    <cfset consoleoutput(true)>
    <cfset console("------------SEARCHSERVER: SERVER STARTUP------------------")>
    <!--- Delete any .lock file --->
    <cftry>
      <cfset console("---SEARCHSERVER: START: Lock file cleanup---")>
      <cfdirectory action="list" directory="#GetTempdirectory()#" listinfo="name" filter="*.lock" name="l">
      <cfif l.recordcount NEQ 0>
        <cfloop query="l">
          <cfset filedelete(GetTempdirectory() & name)>
        </cfloop>
        <cfset consoleoutput(true)>
        <cfset console("SEARCHSERVER: All .lock files have been deleted")>
      <cfelse>
        <cfset consoleoutput(true)>
        <cfset console("SEARCHSERVER: No .lock file to remove")>
      </cfif>
      <cfset console("---SEARCHSERVER: DONE: Lock file cleanup---")>
      <cfcatch type="any">
        <cfset consoleoutput(true)>
        <cfset console("SEARCHSERVER: Lock removal error #cfcatch#")>
      </cfcatch>
    </cftry>

    <cftry>
      <cfset console("------------SEARCHSERVER: ENABLING CRON------------------")>
      <cfset cronEnable(true) />
      <cfcatch type="any">
        <cfset consoleoutput(true)>
        <cfset console("------------ SEARCHSERVER: Cron error !!!!!!!!!!!!!!!!!!!!!!!!!")>
        <cfset console(cfcatch)>
      </cfcatch>
    </cftry>
    <cftry>
      <cfset console("------------SEARCHSERVER: ENABLING CRON DIRECTORY------------------")>
       <cfset CronSetDirectory("/cron") />
      <cfcatch type="any">
        <cfset consoleoutput(true)>
        <cfset console("------------ SEARCHSERVER: Cron error !!!!!!!!!!!!!!!!!!!!!!!!!")>
        <cfset console(cfcatch)>
      </cfcatch>
    </cftry>

    <!--- <cfset console("---START: Cache Setup---")> --->
    
    <!--- Create the cache --->
   <!---  <cfset cacheregionnew(
      region="razcache",
      props=
      {
        type : 'memorydisk'
      }
    )> --->

    <!--- READ the documentation at http://wiki.razuna.com/display/ecp/Configure+Caching !!! --->

    <!--- Memcached / CouchBase --->
    <!--- 
    <cfset cacheregionnew(
    region="razcache",
    props=
        {
        type : 'memcached',
        server : '127.0.0.1:11211',
        waittimeseconds : 5
        }
    )>
    --->
    
    <!--- MongoDB --->
    <!--- 
    <cfset cacheregionnew(
    region="razcache",
    props=
        {
      type : 'mongo',
      server : '10.0.0.1:27017 10.0.0.2:27017',
      db : 'razcache',
      collection : 'nameofregion',
      user : 'username',
      password : 'password'
      }
    )>
    --->
     <!--- <cfset console("---DONE: Cache Setup---")> --->
     <cfset console("---------------SEARCHSERVER: FINISHED---------------------")>

  </cffunction>

</cfcomponent>