/**
* Sentry SDK for Lucee
*
* This CFC is based on the original raven-cfml client developed
* by jmacul2 (https://github.com/jmacul2/raven-cfml)
*
* The CFC has been updated to full script with support to instantiate
* and use as a singleton. Also some functions have been rewritten to
* use either new ColdFusion language enhancements or existing ACF functions.
*
* This CFC is for use with Lucee CFML 5.3.6 and up, it has not been tested with ColdFusion Server
*
* Sentry SDK Documentation
* https://docs.sentry.io/clientdev/
*
*/
component displayname="sentry" output="false" accessors="true"{

	property name="environment" type="string";
	property name="levels" type="array";
	property name="logger" type="string" default="sentry-cfml";
	property name="platform" type="string" default="cfml";
	property name="release" type="string";
	property name="privateKey";
	property name="projectID";
	property name="publicKey";
	property name="version" type="string" default="1.0.0" hint="sentry-cfml version";
	property name="sentryUrl" type="string" default="https://sentry.io";
	property name="sentryVersion" type="string" default="7";
	property name="serverName" type="string";

	/**
	* @release The release version of the application.
	* @environment The environment name, such as ‘production’ or ‘staging’.
	* @DSN A DSN string to connect to Sentry's API, the values can also be passed as individual arguments
	* @publicKey The Public Key for your Sentry Account
	* @privateKey The Private Key for your Sentry Account
	* @projectID The ID Sentry Project
	* @sentryUrl The Sentry API url which defaults to https://sentry.io
	* @serverName The name of the server, defaults to cgi.server_name
	*/
	function init(
		required string release,
		required string environment,
		string DSN,
		string publicKey,
		string privateKey,
		numeric projectID,
		string sentryUrl,
		string serverName = cgi.server_name
	) {
		// set keys via DSN or arguments
		if (arguments.keyExists("DSN") && len(trim(arguments.DSN))){
			parseDSN(arguments.DSN);
		}
		else if (
			( arguments.keyExists("publicKey") && len(trim(arguments.publicKey)) ) &&
			( arguments.keyExists("privateKey") && len(trim(arguments.privateKey)) ) &&
			( arguments.keyExists("projectID") && len(trim(arguments.projectID)) )
		) {
			setPublicKey(arguments.publicKey);
			setPrivateKey(arguments.privateKey);
			setProjectID(arguments.projectID);
		}
		else {
			throw(message = "You must pass in a valid DSN or Project Keys and ID to instantiate the Sentry CFML Client.");
		}
		// set defaults
		setLevels(["fatal","error","warning","info","debug"]);
		// set required
		setEnvironment(arguments.environment);
		setRelease(arguments.release);
		// set optional
		setServerName(arguments.serverName);
		// overwrite defaults
		if ( arguments.keyExists("sentryUrl") && len(trim(arguments.sentryUrl)) ) {
			setSentryUrl(arguments.sentryUrl);
        }
	}

	/**
	* Parses a valid Sentry DSN
	* {PROTOCOL}://{PUBLIC_KEY}@{HOST}/{PATH}{PROJECT_ID}
	* https://docs.sentry.io/clientdev/overview/#parsing-the-dsn
	*/
	private void function parseDSN(required string DSN, boolean legacy = false) {
		var pattern = "^(?:(\w+):)?\/\/(\w+)?@([\w\.-\:\_]+)\/(.*)";
		var patternCnt = 4;
		if(arguments.legacy == true) {
			pattern = "^(?:(\w+):)?\/\/(\w+):(\w+)?@([\w\.-]+)\/(.*)";
			patternCnt = 5;
		}
		var result	 = reFind(pattern,arguments.DSN,1,true);
		var segments = [];

		var posLen = result.pos.len();
		for(var i=2; i <= posLen; i++){
			segments.append(mid(arguments.DSN, result.pos[i], result.len[i]));
		}

		var segmentsLen = segments.len();
		if (compare(segmentsLen,patternCnt)){
			throw(message="Error parsing DSN");
		}
		// set the properties
		setSentryUrl(segments[1] & "://" & segments[patternCnt-1]);
		setPublicKey(segments[2]);
		setProjectID(segments[patternCnt]);
		if(legacy == true) {
			setPrivateKey(segments[3]);
		}
	}

	/**
	* Validates that a correct level was set for a capture
	* The allowed levels are:
	*	 "fatal","error","warning","info","debug"
	*/
	private void function validateLevel(required string level) {
		if(!getLevels().find(arguments.level)) {
			throw(message="Error Type must be one of the following : " & getLevels().toString());
        }
	}

	/**
	* Capture a message
	* https://docs.sentry.io/clientdev/interfaces/message/
	*
	* @message the raw message string ( max length of 1000 characters )
	* @level The level to log
	* @path The path to the script currently executing
	* @params an optional list of formatting parameters
	* @cgiVars Parameters to send to Sentry, defaults to the CGI Scope
	* @useThread Option to send post to Sentry in its own thread
	* @userInfo Optional Struct that gets passed to the Sentry User Interface
	*/
	public any function captureMessage(
		required string message,
		string level = "info",
		string path = "",
		array params,
		any cgiVars = cgi,
		boolean useThread = false,
		struct userInfo = {},
		string requestUid = lcase(replace(createUUID(), "-", "", "all"))
	) {
		var sentryMessage = {};

		validateLevel(arguments.level);

		if (len(trim(arguments.message)) > 1000) {
			arguments.message = left(arguments.message,997) & "...";
        }

		sentryMessage = {
			"message": arguments.message,
			"level": arguments.level
		};

		if(structKeyExists(arguments,"params")) {
			sentryMessage["params"] = arguments.params;
        }

		capture(
			captureStruct: sentryMessage,
			path: arguments.path,
			cgiVars: arguments.cgiVars,
			useThread: arguments.useThread,
			userInfo: arguments.userInfo,
			requestUid: arguments.requestUid
		);
	}

	/**
	* @exception The exception
	* @level The level to log
	* @path The path to the script currently executing
	* @useThread Option to send post to Sentry in its own thread
	* @userInfo Optional Struct that gets passed to the Sentry User Interface
	* @showJavaStackTrace Passes Java Stack Trace as a string to the extra attribute
	* @oneLineStackTrace Set to true to render only 1 tag context. This is not the Java Stack Trace this is simply for the code output in Sentry
	* @removeTabsOnJavaStackTrace Removes the tab on the child lines in the Stack Trace
	* @additionalData Additional metadata to store with the event - passed into the extra attribute
	* @cgiVars Parameters to send to Sentry, defaults to the CGI Scope
	* @useThread Option to send post to Sentry in its own thread
	* @userInfo Optional Struct that gets passed to the Sentry User Interface	*
	*/
	public any function captureException(
		required any exception,
		string level = "error",
		string path = "",
		boolean oneLineStackTrace = false,
		boolean showJavaStackTrace = false,
		boolean removeTabsOnJavaStackTrace = false,
		any additionalData,
		any cgiVars = cgi,
		boolean useThread = false,
		struct userInfo = {},
		string requestUid = lcase(replace(createUUID(), "-", "", "all"))
	) {
		var sentryException = {};
		var sentryExceptionExtra = {};
		var file = "";
		var fileArray = "";
		var currentTemplate = "";
		var tagContext = arguments.exception.TagContext;
		var i = 1;
		var st = "";

		validateLevel(arguments.level);

		/*
		* CORE AND OPTIONAL ATTRIBUTES
		* https://docs.sentry.io/clientdev/attributes/
		*/
		sentryException = {
			"message": arguments.exception.message & " " & arguments.exception.detail,
			"level": arguments.level,
			"culprit": arguments.exception.message
		};

		if (arguments.showJavaStackTrace){
			st = reReplace(arguments.exception.StackTrace, "\r", "", "All");
			if (arguments.removeTabsOnJavaStackTrace) {
				st = reReplace(st, "\t", "", "All");
            }
			sentryExceptionExtra["Java StackTrace"] = listToArray(st,chr(10));
		}

		if (!isNull(arguments.additionalData)) {
			sentryExceptionExtra["Additional Data"] = arguments.additionalData;
        }

		if (structCount(sentryExceptionExtra)) {
			sentryException["extra"] = sentryExceptionExtra;
        }

		/*
		* STACKTRACE INTERFACE
		* https://docs.sentry.io/clientdev/interfaces/stacktrace/
		*/
		if (arguments.oneLineStackTrace)
			tagContext = [tagContext[1]];

		stacktrace = [];

		var contextLen = tagContext.len();
		for (i=1; i <= contextLen; i++) {
			if (compareNoCase(tagContext[i]["TEMPLATE"],currentTemplate)) {
				fileArray = [];
				if (fileExists(tagContext[i]["TEMPLATE"])) {
					file = fileOpen(tagContext[i]["TEMPLATE"], "read");
					while (!fileIsEOF(file)) {
						arrayAppend(fileArray, fileReadLine(file));
                    }
					fileClose(file);
				}
				currentTemplate = tagContext[i]["TEMPLATE"];
			}

            var fileArrayLen = fileArray.len();
			stacktrace[i] = {
				"abs_path"	 = tagContext[i]["TEMPLATE"],
				"filename"	 = tagContext[i]["TEMPLATE"],
				"lineno"	 = tagContext[i]["LINE"]
			};

			// The name of the function being called
			if (i == 1) {
				stacktrace[i]["function"] = "column #tagContext[i]["COLUMN"]#";
            } else {
				stacktrace[i]["function"] = tagContext[i]["ID"];
            }

			// for source code rendering
			stacktrace[i]["pre_context"] = [];
			if (tagContext[i]["LINE"]-3 >= 1) {
				stacktrace[i]["pre_context"][1] = fileArray[tagContext[i]["LINE"]-3];
            }
			if (tagContext[i]["LINE"]-2 >= 1) {
				stacktrace[i]["pre_context"][1] = fileArray[tagContext[i]["LINE"]-2];
            }
			if (tagContext[i]["LINE"]-1 >= 1) {
				stacktrace[i]["pre_context"][2] = fileArray[tagContext[i]["LINE"]-1];
            }
			if (fileArrayLen) {
				stacktrace[i]["context_line"] = fileArray[tagContext[i]["LINE"]];
            }

			stacktrace[i]["post_context"] = [];
			if (fileArrayLen >= tagContext[i]["LINE"]+1) {
				stacktrace[i]["post_context"][1] = fileArray[tagContext[i]["LINE"]+1];
            }
			if (fileArrayLen >= tagContext[i]["LINE"]+2) {
				stacktrace[i]["post_context"][2] = fileArray[tagContext[i]["LINE"]+2];
            }
		}
		
		/*
		* EXCEPTION INTERFACE
		* https://docs.sentry.io/clientdev/interfaces/exception/
		*/
		sentryException["exception"] = {
			"values": [
				{
					"value": arguments.exception.message & " " & arguments.exception.detail,
					"type": arguments.exception.type & " Error",
					"stacktrace": {
						"frames": stacktrace
					}
				}
			]
			
		};

		capture(
			captureStruct: sentryException,
			path: arguments.path,
			cgiVars: arguments.cgiVars,
			useThread: arguments.useThread,
			userInfo: arguments.userInfo,
			requestUid: arguments.requestUid
		);
	}

	/**
	* Prepare message to post to Sentry
	*
	* @captureStruct The struct we are passing to Sentry
	* @cgiVars Parameters to send to Sentry, defaults to the CGI Scope
	* @path The path to the script currently executing
	* @useThread Option to send post to Sentry in its own thread
	* @userInfo Optional Struct that gets passed to the Sentry User Interface
	*/
	public void function capture(
		required any captureStruct,
		any cgiVars = cgi,
		string path = "",
		boolean useThread = false,
		struct userInfo = {},
		string requestUid = lcase(replace(createUUID(), "-", "", "all"))
	) {
		var jsonCapture = "";
		var signature = "";
		var header = "";
		var timeVars = getTimeVars();
		var httpRequestData = getHTTPRequestData();

		// Add global metadata
		arguments.captureStruct["event_id"] = arguments.requestUid;
		arguments.captureStruct["timestamp"] = timeVars.timeStamp;
		arguments.captureStruct["logger"] = getLogger();
		arguments.captureStruct["project"] = getProjectID();
		arguments.captureStruct["server_name"] = getServerName();
		arguments.captureStruct["platform"] = getPlatform();
		arguments.captureStruct["release"] = getRelease();
		arguments.captureStruct["environment"] = getEnvironment();
		arguments.captureStruct['transaction'] = arguments.path;

		/*
		* User interface
		* https://docs.sentry.io/clientdev/interfaces/user/
		*
		* {
		*	 "id" : "unique_id"
		*	 "email" : "my_user"
		*	 "ip_address" : "foo@example.com"
		*	 "username" : ""127.0.0.1"
		* }
		*
		* All other keys are stored as extra information but not specifically processed by sentry.
		*/
		if (!structIsEmpty(arguments.userInfo))
			arguments.captureStruct["user"] = arguments.userInfo;

		// Prepare path for HTTP Interface
		arguments.path = trim(arguments.path);
		if (!len(arguments.path))
			arguments.path = "http" & (arguments.cgiVars.server_port_secure ? "s" : "") & "://" & arguments.cgiVars.server_name & arguments.cgiVars.script_name;

		// HTTP interface
		// https://docs.sentry.io/clientdev/interfaces/http/
		arguments.captureStruct["request"] = {
			"sessions": isDefined('session') ? session : {},
			"url": arguments.path,
			"method": arguments.cgiVars.request_method,
			"data": form,
			"query_string": arguments.cgiVars.query_string,
			"cookies": cookie,
			"env": arguments.cgiVars,
			"headers": httpRequestData.headers
		};

		// encode data
		jsonCapture = serializeJSON(arguments.captureStruct);

		// prepare header
		header = "Sentry sentry_version=#getSentryVersion()#, sentry_timestamp=#timeVars.time#, sentry_key=#getPublicKey()#, sentry_client=#getLogger()#/#getVersion()#";
		// post message
		if (arguments.useThread){
			cfthread(
				action= "run",
				name= "sentry-thread-" & createUUID(),
				header= header,
				jsonCapture= jsonCapture
			){
				post(header,jsonCapture);
			}
		} else {
			post(header,jsonCapture);
		}
	}

	/**
	* Post message to Sentry
	*/
	private void function post(
		required string header,
		required string json
	) {
		var http = {};
		// send to sentry via REST API Call
		cfhttp(
			url	 : getSentryUrl() & "/api/#getProjectID()#/store/",
			method	 : "post",
			timeout : "2",
			result	 : "http"
		){
			cfhttpparam(type="header",name="X-Sentry-Auth",value=arguments.header);
			cfhttpparam(type="body",value=arguments.json);
		}
		
		// TODO : Honor Sentry’s HTTP 429 Retry-After header any other errors
		if(http.status_code == 429 && http.responseheader.keyExists('Retry-After')) {

		}

		// TODO: Honor Sentry's Rate Limits
		if(http.responseheader.keyExists('X-Sentry-Rate-Limits')) {

		}
	}

	/**
	* Get UTC time values
	*/
	private struct function getTimeVars() {
		var time = now();
		var timeVars = {
			"time": time.getTime(),
			"utcNowTime": dateConvert("Local2UTC", time)
		};
		timeVars.timeStamp = dateTimeFormat(timeVars.utcNowTime, "ISO");
		return timeVars;
	}
}
