#!/usr/bin/env bash

# Scan for certificates on a given URL, catalog any certs found along with their expiration times.
# Compare the results of the current run with saves results from a previous run to check for changes.
# Give warning on expiry time, or certificate changes.
#
# Author: Robert.Maracle
#  
# Notes:
# There are different ways to pass the needed parameters to this script.
# -Defaults: there are the script defaults, that are hard coded into this script. Not all parameters have defaults.
# -Env Vars: there are environment variables that are read in at run time. This is useful for containerizing this script. Defaults are over written by env vars.
# TODO: -Config file: read in a config file. Parameters set in the config file will overwrite any EnvVars and defaults.
# -Options and Arguments: there are options and arguments that can be passed on the CLI at run time. These overwrite any parameters set by the above methods.


###############################################################################
## Initialize some variables
###############################################################################
HOSTNAME=$(uname -n)
# TODO: Expect hostname to be FQDN, this may not always be true, so handle it: Get proper FQDN.

# Remove the first ".", and everything after it from $HOSTNAME. I.e. "mybox" will result from "mybox.mysite.company.com"
SHORT_NAME=${HOSTNAME%%.*} 

 # Remove the first ".", and everything before it from $HOSTNAME. I.e. "mysite.company.com" will result from "mybox.mysite.company.com"
FULL_DOMAIN=${HOSTNAME#*.}

# Remove the first ".", and everything after it from $FULL_DOMAIN. I.e. "mysite" will result from "mybox.mysite.company.com"
DOMAIN=${FULL_DOMAIN%%.*} 

# Get a timestamp in UTC (in seconds since epoch) to avoid timezone ambiguity.

NOW=$(date -u +%s)

# Setup some default values
DEF_PORT=443

#DEF_DEBUG=0 # Silent. No additional debug output at all
#DEF_DEBUG=1 # Write only ERRORs to stderr
#DEF_DEBUG=2 # Write ERRORs to stderr, and WARNINGs to stdout
#DEF_DEBUG=3 # Write ERRORs to stderr, WARNINGs and INFOs to stdout
DEF_DEBUG=4 # Write ERRORs to stderr, WARNINGs, INFOs, and DEBUGs to stdout

DEF_DATADIR="."
DEF_INFILE=""
DEF_JAVA="${JAVA_HOME}"
DEF_KEYSTORE="${JAVA_HOME}/lib/security/cacerts"
DEF_PORT="443"
DEF_SERVER="${HOSTNAME}"
DEF_CAPASSWORD="changeit"

###############################################################################
## Debug setup
###############################################################################
debugit()
    { # Output debug messages depending on how $DEBUG_LEVEL is set.
      # first argument is the type of message. Must be one of the following:
      #    ERROR
      #    WARNING
      #    INFO
      #    DEBUG
      # Example: 
      #   debugit INFO "This is how you use the debug feature."
      # Example output:
      #   INFO: This is how you use the debug feature.

    case ${DEBUG_LEVEL} in
        0)
            return 0
        ;;
        1)
            case ${1} in
                ERROR)
                    shift
                    >&2 echo -e "ERROR: $@"
                    return 0
                ;;
                WARNING)
                    return 0
                ;;
                INFO)
                    return 0
                ;;
                DEBUG)
                    return 0
                ;;
                *)
                    >&2 echo -e "INTERNAL ERROR - Debug message type '$1' is invalid."
                    return 1
                ;;
            esac
        ;;
        2)
            case ${1} in
                ERROR)
                    shift
                    >&2 echo -e "ERROR: $@"
                    return 0
                ;;
                WARNING)
                    shift
                    echo -e "WARNING: $@"
                    return 0
                ;;
                INFO)
                    return 0
                ;;
                DEBUG)
                    return 0
                ;;
                *)
                    >&2 echo -e "INTERNAL ERROR - Debug message type '$1' is invalid."
                    return 1
                ;;
            esac
        ;;
        3)
            case ${1} in
                ERROR)
                    shift
                    >&2 echo -e "ERROR: $@"
                    return 0
                ;;
                WARNING)
                    shift
                    echo -e "WARNING: $@"
                    return 0
                ;;
                INFO)
                    shift
                    echo -e "INFO: $@"
                    return 0
                ;;
                DEBUG)
                    return 0
                ;;
                *)
                    >&2 echo "INTERNAL ERROR - Debug message type '$1' is invalid."
                    return 1
                ;;
            esac
        ;;
        4)
            case ${1} in
                ERROR)
                    shift
                    >&2 echo -e "ERROR: $@"
                    return 0
                ;;
                WARNING)
                    shift
                    echo -e "WARNING: $@"
                    return 0
                ;;
                INFO)
                    shift
                    echo -e "INFO: $@"
                    return 0
                ;;
                DEBUG)
                    shift
                    echo -e "DEBUG: $@"
                    return 0
                ;;
                *)
                    >&2 echo "INTERNAL ERROR - Debug message type '$1' is invalid."
                    return 1
                ;;
            esac
        ;;
        *)
            echo "INTERNAL ERROR - Invalid debug level '${debug_level}'"
            # echo "Setting debug level to default of ${DEF_DEBUG}"
            # debug_level=${DEF_DEBUG}
        ;;
    esac
    }

if [ ! -z $SSL_WATCHDOG_DEBUG ]
    then
        ENV_DEBUG=$SSL_WATCHDOG_DEBUG
fi

        

###############################################################################
## Help
###############################################################################


disp_help()
    { # Print script help to screen, and exit.
      # Optional argument will set exit value.
        echo -e "\nTool to examine SSL certificates, and provide notice if there is a condition that needs attention.\n"    
        echo -e "\tUsage: $0 [COMMAND] {OPTIONS} [ARGUMENTS]"
        echo -e "\nCommands:"
        echo -e "\tex\t- Example command"
        echo -e "\nOptions:"
        echo -e "\t-P\n\tor\n\t--password"
        echo -e "\t\t\tThe password to the java keysotre/cacerts file.\n"
        echo -e "\t-d\n\tor\n\t--data|--datadir"
        echo -e "\t\t\tThe directory used to store output data.\n"
        echo -e "\t-f\n\tor\n\t--file"
        echo -e "\t\t\tCertificate file to examine.\n"
        echo -e "\t-h\n\tor\n\t--help"
        echo -e "\t\t\tPrint this help message."
        echo -e "\t-j\n\tor\n\t--java|--jdk|--jre"
        echo -e "\t\t\tPath to the Java runtime. E.g. '/opt/java'.\n"
        echo -e "\t-k\n\tor\n\t--keystore|--cacerts"
        echo -e "\t\t\tthe path to the java keystore (cacerts file) to operate on.\n"
        echo -e "\t-p\n\tor\n\t--port"
        echo -e "\t\t\tSSL Port that should be examined on the server. Requires '-s'\n"
        echo -e "\t|-s\n\tor\n\t--server"
        echo -e "\t\t\tSSL server to examine.\n"
        echo -e "\t-v|-vv|-vvv|-vvvv\n\tor\n\t--verbose"
        echo -e "\t\t\tSet verbosity level 0-4:\n\t\t\t0=silent\n\t\t\t1=errors only\n\t\t\t2=errors and warnings\n\t\t\t3=errors, warnings, and info\n\t\t\t4=full debug output\n"
        echo -e "\nArguments:"
        echo -e "\t- FILENAME1 ... FILENAMEn\n\t\tWhere FILENAME is the name of a cert file(s) to examine."
        echo
        if [ $# = 1 ]
            then
                if [[ "$1" =~ '^[0-9]+$' ]]
                    then exit $1
                    else exit 2
                fi
            else
                exit
        fi
    }

###############################################################################
## Helper Functions
###############################################################################
SetInputVar()
    { # Take a list of potential inputs for a given parameter, and use the one with the hiest priority.
      #
      # Since there are many way to set a single parameter (Default, EnvVar, CLI, ...)
      # we may have a case where we have several, possibly different values for the same single parameter.
      # This funtion expects a list of potential arguments in priority order (lowest priority first, highest last), 
      # and simply sets the last one as the variable output. Arguments may be an empty string. In such a case, it is simply skipped.
    local outvar
    for var in $@
        do
            outvar=${var}
        done
    echo ${outvar}
    }


DEBUG_LEVEL=$(SetInputVar ${DEF_DEBUG} ${ENV_DEBUG} ${CFG_DEBUG} ${OPT_DEBUG})
debugit DEBUG "DEBUG_LEVEL set to ${DEBUG_LEVEL}"

###############################################################################
## CLI processing: Command, Options, and Arguments
###############################################################################

# Commands
if [ $# -ge 1 ]
    then
        debugit DEBUG "Parsing command"
        if [ ${1#-} = $1 ]
            then
                commandArg="$1"
                shift
                debugit DEBUG "Command specified is: ${commandArg}"

                case ${commandArg} in
                    yyyy)
                        debugit DEBUG "Recognized command: ${commandArg}"
                    ;;
                    *)
                        debugit DEBUG "Unknown command: ${commandArg}"
                        debugit ERROR "Unknown command: ${commandarg}"
                        disp_help 1
                esac
            else
                commandArg="NULL"
        fi
    else
        debugit DEBUG "No command specified"
        disp_help
fi

# Options
optspec="P:d:f:hj:k:p:s:v:"
while getopts "${optspec}" opt
    do
        case "${opt}" in
            -)
                case "${OPTARG}" in
                    xxxx)
                        OPT_xxxx="${!OPTIND}"
                        (( OPTIND++ ))
                    ;;
                    xxxx=*)
                        OPT_xxxx=${OPTARG#*=}
                    ;;
                    data|datadir)
                        OPT_DATADIR="${!OPTIND}"
                        (( OPTIND++ ))
                    ;;
                    data=*|datadir=*)
                        OPT_DATADIR=${OPTARG#*=}
                    ;;
                    keystore|cacerts)
                        OPT_KEYSTORE="${!OPTIND}"
                        (( OPTIND++ ))
                    ;;
                    keystore=*|cacerts=*)
                        OPT_KEYSTORE=${OPTARG#*=}
                    ;;
                    java|jre|jdk)
                        OPT_JAVA="${!OPTIND}"
                        (( OPTIND++ ))
                    ;;
                    java=*|jre=*|jdk=*)
                        OPT_JAVA=${OPTARG#*=}
                    ;;
                    file)
                        OPT_INFILE="${!OPTIND}"
                        (( OPTIND++ ))
                    ;;
                    file=*)
                        OPT_INFILE=${OPTARG#*=}
                    ;;
                    server)
                        OPT_SERVER="${!OPTIND}"
                        (( OPTIND++ ))
                    ;;
                    server=*)
                        OPT_SERVER=${OPTARG#*=}
                    ;;
                    port)
                        OPT_PORT="${!OPTIND}"
                        (( OPTIND++ ))
                    ;;
                    port=*)
                        OPT_PORT=${OPTARG#*=}
                    ;;
                    verbose)
                        OPT_DEBUG="${!OPTIND}"
                        (( OPTIND++ ))
                        debugit DEBUG "debug_level set to '${OPT_DEBUG}'"
                    ;;
                    verbose=*)
                        OPT_DEBUG=${OPTARG#*=}
                        debugit DEBUG "debug_level set to '${OPT_DEBUG}'"
                    ;;
                    # v|vv|vvv|vvvv)
                    #     case "${OPTARG}" in
                    #         v)
                    #             debug_level=1
                    #         ;;
                    #         vv)
                    #             debug_level=2
                    #         ;;
                    #         vvv)
                    #             debug_level=3
                    #         ;;
                    #         vvvv)
                    #             debug_level=4
                    #         ;;
                    #     esac
                    #     debugit DEBUG "debug_level set to '${debug_level}'"
                    # ;;
                    *)
                        if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                            echo "Unknown option --${OPTARG}" >&2
                        fi
                    ;;
                esac
            ;;
            d)
                OPT_DATADIR=${OPTARG}
            ;;
            f)
                OPT_INFILE=${OPTARG}
            ;;
            j)
                OPT_JAVA=${OPTARG}
            ;;
            k)
                OPT_KEYSTORE=${OPTARG}
            ;;
            s)
                OPT_SERVER=${OPTARG}
            ;;
            p)
                OPT_PORT=${OPTARG}
            ;;
            v)
                case ${OPTARG} in
                    "0")
                        OPT_DEBUG=0
                    ;;
                    "1")
                        OPT_DEBUG=1
                    ;;
                    "2")
                        OPT_DEBUG=2
                    ;;
                    "3")
                        OPT_DEBUG=3
                    ;;
                    "4")
                        OPT_DEBUG=4
                    ;;
                    "")
                        OPT_DEBUG=3
                    ;;
                    v*)
                        case "${OPTARG}" in
                            v)
                                OPT_DEBUG=2
                            ;;
                            vv)
                                OPT_DEBUG=3
                            ;;
                            vvv)
                                OPT_DEBUG=4
                            ;;
                            *)
                                >&2 echo "invalid debug level specified: 'v${OPTARG}'"
                                disp_help 1
                            ;;
                        esac
                        debugit DEBUG "debug_level set to '${OPT_DEBUG}'"
                    ;;
                    *)
                        >&2 echo "invalid debug level specified: '${OPTARG}'"
                        disp_help 1
                    ;;
                esac
                debugit DEBUG "debug_level set to '${debug_level}'"
            ;;
            h)
                disp_help 0
            ;;
        esac
    done
shift $((OPTIND-1))

# Arguments
debugit DEBUG "Parsing arguments"
ARG_INFILE=()
while [ $# -gt 0 ]
    do
        ARG_INFILE=( ${ARG_INFILE[@]} $1 )
        shift
    done
debugit DEBUG "Arguments found: '${ARG_INFILE[@]}'"

###############################################################################
## Environment Variable Processing
###############################################################################
debugit DEBUG "Parsing environment variables"

if [ -z "$SSL_WATCHDOG_DATADIR" ]
    then
        ENV_DATADIR=""
    else
        ENV_DATADIR="$SSL_WATCHDOG_DATADIR"
        debugit DEBUG "EnvVar 'SSL_WATCHDOG_DATADIR' found. Setting 'ENV_DATADIR' to ${ENV_DATADIR}"
fi
if [ -z "$SSL_WATCHDOG_CAPASSWORD" ]
    then
        ENV_CAPASSWORD=""
    else
        ENV_CAPASSWORD="$SSL_WATCHDOG_CAPASSWORD"
        debugit DEBUG "EnvVar 'SSL_WATCHDOG_CAPASSWORD' found. Setting 'ENV_CAPASSWORD' to ${ENV_CAPASSWORD}"
fi
if [ -z "$SSL_WATCHDOG_INFILE" ]
    then
        ENV_INFILE=""
    else
        ENV_INFILE="$SSL_WATCHDOG_INFILE"
        debugit DEBUG "EnvVar 'SSL_WATCHDOG_INFILE' found. Setting 'ENV_INFILE' to ${ENV_INFILE}"
fi
if [ -z "$SSL_WATCHDOG_JAVA" ]
    then
        ENV_JAVA=""
    else
        ENV_JAVA="$SSL_WATCHDOG_JAVA"
        debugit DEBUG "EnvVar 'SSL_WATCHDOG_JAVA' found. Setting 'ENV_JAVA' to ${ENV_JAVA}"
fi
if [ -z "$SSL_WATCHDOG_KEYSTORE" ]
    then
        ENV_KEYSTORE=""
    else
        ENV_KEYSTORE="$SSL_WATCHDOG_KEYSTORE"
        debugit DEBUG "EnvVar 'SSL_WATCHDOG_KEYSTORE' found. Setting 'ENV_KEYSTORE' to ${ENV_KEYSTORE}"
fi
if [ -z "$SSL_WATCHDOG_PORT" ]
    then
        ENV_PORT=""
    else
        ENV_PORT="$SSL_WATCHDOG_PORT"
        debugit DEBUG "EnvVar 'SSL_WATCHDOG_PORT' found. Setting 'ENV_PORT' to ${ENV_PORT}"
fi
if [ -z "$SSL_WATCHDOG_SERVER" ]
    then
        ENV_PORT=""
    else
        ENV_PORT="$SSL_WATCHDOG_SERVER"
        debugit DEBUG "EnvVar 'SSL_WATCHDOG_SERVERD' found. Setting 'ENV_SERVER' to ${ENV_SERVER}"
fi




###############################################################################
## Digest Script Inputs (Defaults, EnvVar, CLI, Config)
###############################################################################

DEBUG_LEVEL=$(SetInputVar ${DEF_DEBUG} ${ENV_DEBUG} ${CFG_DEBUG} ${OPT_DEBUG})
debugit DEBUG "Set 'DEBUG_LEVEL' to '${DEBUG_LEVEL}'"
DATADIR=$(SetInputVar ${DEF_DATADIR} ${ENV_DATADIR} ${CFG_DATADIR} ${OPT_DATADIR})
debugit DEBUG "Set 'DATADIR' to '${DATADIR}'"
TMP_INFILE=$(SetInputVar ${DEF_INFILE} ${ENV_INFILE} ${CFG_INFILE} ${OPT_INFILE})
debugit DEBUG "Set 'INFILE' to '${INFILE}'"
JAVA=$(SetInputVar ${DEF_JAVA} ${ENV_JAVA} ${CFG_JAVA} ${OPT_JAVA})
debugit DEBUG "Set 'JAVA' to '${JAVA}'"
KEYSTORE=$(SetInputVar ${DEF_KEYSTORE} ${ENV_KEYSTORE} ${CFG_KEYSTORE} ${OPT_KEYSTORE})
debugit DEBUG "Set 'KEYSTORE' to '${KEYSTORE}'"
PORT=$(SetInputVar ${DEF_PORT} ${ENV_PORT} ${CFG_PORT} ${OPT_PORT})
debugit DEBUG "Set 'PORT' to '${PORT}'"
SERVER=$(SetInputVar ${DEF_SERVER} ${ENV_SERVER} ${CFG_SERVER} ${OPT_SERVER})
debugit DEBUG "Set 'SERVER' to '${SERVER}'"

# Convert to lower case
SERVER=$(echo ${SERVER} | tr "[A-Z]" "[a-z]")
# Convert comma separated lists to arrays
SERVER=( ${SERVER/,/ } )
debugit DEBUG "Converted comma separated list 'SERVER' to array: '${SERVER[@]}'"
TMP_INFILE=( ${TMP_INFILE/,/ } )
debugit DEBUG "Converted comma separated list 'TMP_INFILE' to array: '${TMP_INFILE[@]}'"
# Detect if the input file was set by DEF/ENV/CFG/OPT or ARG 
if [ ! -z ${ARG_INFILE} ] && [ ! -z ${TMP_INFILE} ]
    then
        debugit DEBUG "INFILE has been set more than one way."
        debugit INFO "It looks like the input file was passed in multiple ways, some of which which may have been ignored.\n\tNext time, try using only one method to set the input file."
        debugit INFO "We have:\n\tDefault input file: '${DEF_INFILE}'\n\tEnvironment Variable: '${ENV_INFILE}'\n\tConfig file: '${CFG_INFILE}'\n\tOption -f: '${OPT_INFILE}'\n\tArgument: ${ARG_INFILE[@]}"
        debugit WARNING "Ignoring all other input files since the input file(s) '${ARG_INFILE[@]}' was passed as an argument."
        TMP_INFILE=(${ARG_INFILE[@]})
fi


###############################################################################
## Sanity checking, and User input sterilization
###############################################################################

# INFILE sanity check: Exists, and is readable?
INFILE_INDEX=0
for f in ${TMP_INFILE[@]}
    do
        if [ -r ${f} ]
            then
                debugit DEBUG "File ${f} exists and is readable."
                INFILE=( ${INFILE[@]} ${f})
            else
                debugit DEBUG "File '${f}' either does not exist, or isn't readable."
                debugit INFO "Please ensure the file '${f}' exists, and has correct permissions set."
                TMP_INFILE=( $(echo ${TMP_INFILE[@]/${TMP_INFILE[${INFILE_INDEX}]}}) )
                if [ ${#INFILE[@]} -gt 0 ]
                    then debugit WARNING "Skipping unreadable file '${f}'"
                    elif [ ${#TMP_INFILE[@]} -gt 0 ]
                        then debugit WARNING "Skipping unreadable file '${f}'"
                    elif [ ${#SERVER[@]} -gt 0 ]
                        then debugit WARNING "Skipping unreadable file '${f}'"
                    else debugit ERROR "Cannot read file '${f}'. Nothing left to do."
                fi
        fi
        ((ARG_INDEX++))
    done
debugit DEBUG "Will examine the following files: ${INFILE[@]}"

# DATADIR sanity check: Exists, and is writable?
if [ -d ${DATADIR} ] && [ -w ${DATADIR} ]
    then
        debugit DEBUG "DATADIR '${DATADIR}' is valid and writable."
    else
        debugit DEBUG "DATADIR '${DATADIR}' is not valid or may not be writable."
        debugit INFO "Please make sure data directory '${DATADIR}' exists and is writable."
        debugit ERROR "Cannot write to data directory '${DATADIR}."
fi

# DEBUG_LEVEL sanity check: Is an integer between 0-4?
case ${DEBUG_LEVEL} in
    0|1|2|3|4)
        debugit DEBUG "Debug level '${DEBUG_LEVEL}' is valid."
    ;;
    *)
        BAD_DEBUG_LEVEL=${DEBUG_LEVEL}
        DEBUG_LEVEL=3
        debugit DEBUG "I don't think this is a valid debug level: '${BAD_DEBUG_LEVEL}'"
        debugit INFO "Debug Level '${BAD_DEBUG_LEVEL}' doesn't seem to be valid. Make sure it is set to a value between 0-4."
        debugit WARNING "Invalid debug level: ${BAD_DEBUG_LEVEL}. Defaulting to debeug level 3."
    ;;
esac

# TODO: JAVA sanity check:  ${JAVA}/bin has needed exucutable, and is readable?
# TODO: Separate out KEYTOOL, and KEYSTORE checks
JAVA_DIRS=( ${JAVA} ${JAVA_HOME} ${JRE_HOME} /usr /usr/libexec/java_home /System/Library/Frameworks/JavaVM.framework/Versions/CurrentJDK/Home )
KEYTOOL_PATH="/bin/keytool"

for dir in ${JAVA_DIRS[@]}
    do
        debugit DEBUG "Looking for keytool in ${dir}${KEYTOOL_PATH}..."
        if [ -x ${dir}${KEYTOOL_PATH} ]
            then
                JAVA_DIR=${dir}
                debugit DEBUG "Found keytool in ${dir}${KEYTOOL_PATH}"
                break
            else
                debugit DEBUG "Did not find keytool in ${dir}${KEYTOOL_PATH}"
                continue
        fi
    done
if [ -z "$JAVA_DIR" ]
    then
        JAVA_PATH=$(2>/dev/null which java) && JAVA_DIR=$(2>/dev/null dirname $JAVA_PATH)
        if [ -z "$JAVA_DIR" ]
            then
                debugit DEBUG "JAVA=${JAVA}, JAVA_HOME=${JAVA_HOME}, JRE_HOME=${JRE_HOME}, JAVA_DIR=${JAVA_DIR}, JAVA_PATH=${JAVA_PATH}"
                debugit INFO "Set the JAVA_HOME environment variable, any try again, or specify the path to your JRE/JDK with '-j /path/to/jdk'"
                debugit ERROR "Could not determine the path to java. This is required to process certificates"
        fi
fi
KEYTOOL="${JAVA_DIR}${keytool_path}"
debugit INFO "Using keytool from '${KEYTOOL}'"

# KEYSTORE sanity check: is writable?
if [ -w "${KEYSTORE}" ]
    then
        debugit DEBUG "Using keystore '${KEYSTORE}'"
    elif [ -w "${JAVA_DIR}/lib/security/cacerts" ]
        then
            debugit DEBUG "Keystore '${KEYSTORE}' either doesn't exist, or isn't writable."
            debugit INFO "Please ensure keystore '${KEYSTORE}' exists, and is writable."
            debugit INFO "Found Alternate keystore '${JAVA_DIR}/lib/security/cacerts'"
            KEYSTORE="${JAVA_DIR}/lib/security/cacerts"
            debugit DEBUG "Using keystore '${KEYSTORE}'"
    else
        debugit DEBUG "Keystore '${KEYSTORE}' either doesn't exist, or isn't writable."
        debugit INFO "Please ensure keystore '${KEYSTORE}' exists, and is writable."
        debugit WARNING "Cannot write to keystore '${KEYSTORE}'"
        KEYSTORE="/dev/null"
fi

# PORT sanity check: is an integer between 1 and 65536
if [[ "${PORT}" =~ [1-9]{1,5} ]]
    then
        if [ ${PORT} -gt 65536 ]
            then
                debugit DEBUG "Port value '${PORT}' is invalid."
                debugit INFO "Please provide a valid port number. Port '${PORT}' is not valid."
                debugit ERROR "Invalid port number: '${PORT}'"
            else
                debugit DEBUG "Port '${PORT}' looks valid."
        fi
    else
        debugit DEBUG "Port value '${PORT}' is invalid."
        debugit INFO "Please provide a valid port number. Port '${PORT}' is not valid."
        debugit ERROR "Invalid port number: '${PORT}'"
fi

# SERVER sanity check: is a valid hostname or IP address?

# TODO: SERVER can be an ARRAY! fix it 
# TODO: Do we need to accept IP addresses if certs are based on hostnames?
for box in ${SERVER[@]}
    do
        if [[ "${box}" =~ ^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$ ]]
            then
                debugit DEBUG "Server '${box}' appears to be a valid IP address."
                SERVER_IPS=(${SERVER_IPS[@]} ${box})
            elif [[ "${box}" =~ ^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])(\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]))*$ ]]
                then
                    debugit DEBUG "Server '${box}' appears to be a valid hostname"
                    if SERVER_IP=($(2>&1 host "${box}" | awk '/has address/ {print $NF}') )
                        then
                            debugit DEBUG "Was able to resolve ${box} to IP address ${SERVER_IP[@]}"
                            SERVER_IPS=(${SERVER_IPS[@]} ${SERVER_IP[@]})
                        else
                            debugit DEBUG "Failed to resolve '${box}' to IP address. Got '${SERVER_IP[@]}'"
                            debugit INFO "Failed to resolve '${box}' to a valid IP address."
                            debugit WARNING "Host '${box}' cannot be resolved."
            else
                debugit DEBUG "I don't think '${SERVER}' is a valid hostname or IP address."
                debugit INFO "the specified server '${SERVER}' doesn't appear to be a valid hostname or IP address. Make sure you are not passing a protocol like 'https://' as part of the server name."
                debugit WARNING "Unable to investigate certificate at server '${SERVER}'."
        fi
    done
if [ ${#SERVER_IPS[@]} -eq 0 ]
    then
        debugit DEBUG "No valid server was provided."
    else
        debugit DEBUG "Have the following "

###############################################################################
## Business Funtions
###############################################################################





PullCert()
    { # Pull SSL certificate from $server at $port
      # First argument is expected to be a server name or IP address
      # Second argument is expected to be the port to evaluate. Default port assumed to be 443
      # Third Argument is the path to the java keytool executable
      # Forth argument is the path to the output file of the certificate. Default is ./$server.cer

    local server
    local port
    local tool
    local outfile

    if [ $# -lt 1 ]
        then
            debugit DEBUG "there don't seem to be any arguments remaining for 'server'. Have the following args: '$@'"
            debugit ERROR "INTERNAL ERROR - No server specified."
        else
            debugit DEBUG "setting 'server' to $1"
            server=$1
            shift
    fi
    if [ $# -lt 1 ]
        then
            debugit DEBUG "there don't seem to be any arguments remaining for 'port'. Have the following args: '$@'"
            debugit INFO "Using default port '443'"
            port="443"
        else
            debugit DEBUG "setting 'port' to $1"
            port=$1
            shift
    fi
    if [ $# -lt 1 ]
        then
            debugit DEBUG "there don't seem to be any arguments remaining for 'tool'. Have the following args: '$@'"
            debugit INFO "Using keytool path '${KEYTOOL}'"
            tool="${KEYTOOL}"
        else
            debugit DEBUG "setting 'tool' to $1"
            tool=$1
            shift
    fi
    if [ $# -lt 1 ]
        then
            debugit DEBUG "there don't seem to be any arguments remaining for 'outfile'. Have the following args: '$@'"
            debugit INFO "Using default output path '${DATADIR}/${server}.cer'"
            outfile="${DATADIR}/${server}.cer"
        else
            debugit DEBUG "setting 'outfile' to $1"
            outfile=$1
            shift
    fi
    if [ $# -gt 0 ]
        then
            debugit DEBUG "Have the following args: '$@'"
            debugit ERROR "INTERNAL ERROR - Too many arguments to PullCert()."
    fi

    debugit INFO "Will pull cert from ${server}:${port}"
    ${KEYTOOL} -printcert -sslserver ${server}:${port} -rfc > ${outfile}
    if (( $! != 0 ))
        then
            debugit ERROR "Unable to reliably store certificate."
        else
            debugit INFO "Certificate stored here: ${outfile}"
            debugit DEBUG "$(cat ${outfile})"
    fi
    }


###############################################################################
## Business Logic
###############################################################################