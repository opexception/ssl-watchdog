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
DEF_JAVA=""
DEF_KEYSTORE=""
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
        # case $SSL_WATCHDOG_DEBUG in
        #     0)
        #         debug_level=0
        #         debugit DEBUG "debug_level set to '${debug_level}'"
        #     ;;
        #     1)
        #         debug_level=1 
        #         debugit DEBUG "debug_level set to '${debug_level}'"
        #     ;;
        #     2)
        #         debug_level=2 
        #         debugit DEBUG "debug_level set to '${debug_level}'"
        #     ;;
        #     3)
        #         debug_level=3 
        #         debugit DEBUG "debug_level set to '${debug_level}'"
        #     ;;
        #     4)
        #         debug_level=4 
        #         debugit DEBUG "debug_level set to '${debug_level}'"
        #     ;;
        #     *)
        #         debugit WARNING "Debug level SSL_WATCHDOG_DEBUG='$SSL_WATCHDOG_DEBUG' is invalid!\n\tPlease ensure this env var is empty, or set to a valid level of 1 to 4.\n"
        #     ;;
        # esac
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
                OPT_JAVA=${OPTARG}
            ;;
            j)
                OPT_INFILE=${OPTARG}
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


###############################################################################
## Environment Variable Processing
###############################################################################

if [ -z "$SSL_WATCHDOG_DATADIR" ]
    then
        ENV_DATADIR=""
    else
        ENV_DATADIR="$SSL_WATCHDOG_DATADIR"
fi
if [ -z "$SSL_WATCHDOG_CAPASSWORD" ]
    then
        ENV_CAPASSWORD=""
    else
        ENV_CAPASSWORD="$SSL_WATCHDOG_CAPASSWORD"
fi
if [ -z "$SSL_WATCHDOG_INFILE" ]
    then
        ENV_INFILE=""
    else
        ENV_INFILE="$SSL_WATCHDOG_INFILE"
fi
if [ -z "$SSL_WATCHDOG_JAVA" ]
    then
        ENV_JAVA=""
    else
        ENV_JAVA="$SSL_WATCHDOG_JAVA"
fi
if [ -z "$SSL_WATCHDOG_KEYSTORE" ]
    then
        ENV_KEYSTORE=""
    else
        ENV_KEYSTORE="$SSL_WATCHDOG_KEYSTORE"
fi
if [ -z "$SSL_WATCHDOG_PORT" ]
    then
        ENV_PORT=""
    else
        ENV_PORT="$SSL_WATCHDOG_PORT"
fi
if [ -z "$SSL_WATCHDOG_SERVER" ]
    then
        ENV_PORT=""
    else
        ENV_PORT="$SSL_WATCHDOG_SERVER"
fi



###############################################################################
## Process Script Inputs (Defaults, EnvVar, CLI, Config)
###############################################################################

DEBUG_LEVEL=$(SetInputVar ${DEF_DEBUG} ${ENV_DEBUG} ${CFG_DEBUG} ${OPT_DEBUG})
debugit DEBUG "Set '' to ''"
DATADIR=$(SetInputVar ${DEF_DATADIR} ${ENV_DATADIR} ${CFG_DATADIR} ${OPT_DATADIR})
debugit DEBUG "Set 'DATADIR' to '${DATADIR}'"
INFILE=$(SetInputVar ${DEF_INFILE} ${ENV_INFILE} ${CFG_INFILE} ${OPT_INFILE})
debugit DEBUG "Set 'INFILE' to '${INFILE}'"
JAVA=$(SetInputVar ${DEF_JAVA} ${ENV_JAVA} ${CFG_JAVA} ${OPT_JAVA})
debugit DEBUG "Set 'JAVA' to '${JAVA}'"
KEYSTORE=$(SetInputVar ${DEF_KEYSTORE} ${ENV_KEYSTORE} ${CFG_KEYSTORE} ${OPT_KEYSTORE})
debugit DEBUG "Set 'KEYSTORE' to '${KEYSTORE}'"
PORT=$(SetInputVar ${DEF_PORT} ${ENV_PORT} ${CFG_PORT} ${OPT_PORT})
debugit DEBUG "Set 'PORT' to '${PORT}'"
SERVER=$(SetInputVar ${DEF_SERVER} ${ENV_SERVER} ${CFG_SERVER} ${OPT_SERVER})
debugit DEBUG "Set 'SERVER' to '${SERVER}'"

# Convert comma separated lists to arrays
SERVER=( ${SERVER/,/ } )
debugit DEBUG "Converted comma separated list 'SERVER' to array: '${SERVER[@]}'"
INFILE=( ${INFILE/,/ } )
debugit DEBUG "Converted comma separated list 'INFILE' to array: '${INFILE[@]}'"

# INFILE sanity check
ARG_INDEX=0
for f in ${ARG_INFILE}
    do
        if [ -r ${f} ]
            then
                debugit DEBUG "File ${f} exists and is readable."
                INFILE=( ${INFILE[@]} ${f})
            else
                debugit DEBUG "File '${f}' either does not exist, or isn't readable."
                debugit INFO "Please ensure the file '${f}' exists, and has correct permissions set."
                ARG_INFILE=( $(echo ${ARG_INFILE[@]/${ARG_INFILE[${ARG_INDEX}]}}) )
                if [ ${#INFILE[@]} -gt 0 ] || ${#ARG_INFILE[@]} -gt 0 ]
                    then debugit WARNING "Skipping unreadable file '${f}'"
                    elif [ ${#SERVER[@]} -gt 0 ]
                        then debugit WARNING "Skipping unreadable file '${f}'"
                    else debugit ERROR "Cannot read file '${f}'. Nothing left to do."
                fi
        fi
        ((ARG_INDEX++))
    done
debugit DEBUG "Will examine the following files: ${INFILE[@]}"

# TDOD: check if DATADIR is writable
# TODO: Check if DEBUG_LEVEL is integer between 0-4
# TODO: Check if JAVA has needed exucutable, and readable binaries
# TODO: Check if KEYSTORE is writable
# TODO: Check if port is integer between 1 and 65536
# TODO: Check if SERVER is a valid hostname
###############################################################################
## Funtions
###############################################################################



FindJava()
    { # determine the path to the keytool java utility, and the java keystore we should be storing our certs in.
    # TODO: Allow arguments to overwrite var with script args
    # TODO: Create docstring for this funtion
    # TODO: Decide if a separate function is needed to handle cacerts/keystore path
    local java_dirs
    local keystore_path
    local keytool_path

    java_dirs=( ${JAVA_HOME} ${JRE_HOME} /usr /usr/libexec/java_home /System/Library/Frameworks/JavaVM.framework/Versions/CurrentJDK/Home )
    keystore_path="/lib/security/cacerts"
    keytool_path="/bin/keytool"

    for dir in ${java_dirs[@]}
        do
            debugit DEBUG "Looking for keytool in ${dir}${keytool_path}..."
            if [ -x ${dir}${keytool} ]
                then
                    JAVA_DIR=${dir}
                    debugit DEBUG "Found keytool in ${dir}${keytool_path}"
                    break
                else
                    debugit DEBUG "Did not find keytool in ${dir}${keytool_path}"
                    continue
            fi
            if [ -z "$JAVA_DIR" ]
                then
                    JAVA_PATH=$(2>/dev/null which java)
                    JAVA_DIR=$(2>/dev/null dirname $JAVA_PATH)
                    if [ -z "$JAVA_DIR" ]
                        then
                            debugit DEBUG "JAVA_HOME=${JAVA_HOME}, JRE_HOME=${JRE_HOME}, JAVA_DIR=${JAVA_DIR}, JAVA_PATH=${JAVA_PATH}"
                            debugit INFO "Set the JAVA_HOME environment variable, any try again, or specify the path to your JRE/JDK with '-j /path/to/jdk'"
                            debugit ERROR "Could not determine the path to java."
                        else
                            break
                    fi
            fi
        done
        KEYSTORE="${JAVA_DIR}${keystore_path}"
        KEYTOOL="${JAVA_DIR}${keytool_path}"
        debugit INFO "Using ${KEYTOOL}, and ${KEYSTORE}"
    }

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
            outfile=${DATADIR}/${server}.cer
        else
            debugit DEBUG "setting 'outfile' to $1"
            outfile=$1
            shift
    fi
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