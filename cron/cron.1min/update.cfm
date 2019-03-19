<!--- Call main to update lucene --->
<cfinvoke component="api.main" method="updateLucene">
<cfabort>
<!--- Call main to execute indexing --->
<cfinvoke component="api.main" method="update">