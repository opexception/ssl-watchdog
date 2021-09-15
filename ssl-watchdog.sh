#!/usr/bin/env bash

# Scan for certificates on a given URL, catalog any certs found along with their expiration times.
# Compare the results of the current run with saves results from a previous run to check for changes.
# Give warning on expiry time, or certificate changes.
#
# Author: Robert.Maracle
#  

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
NOW=$(date --utc +%s)


# use the "-v" argument to set debugging.
# Initial debug level. Will be overwritten by "-v" argument, once it has been parsed.
#debug_level=0 # Silent. No additional debug output at all
#debug_level=1 # Write only ERRORs to stderr
#debug_level=2 # Write ERRORs to stderr, and WARNINGs to stdout
#debug_level=3 # Write ERRORs to stderr, WARNINGs and INFOs to stdout
debug_level=4 # Write ERRORs to stderr, WARNINGs, INFOs, and DEBUGs to stdout

# Debug level can also be set via env var "SSL_WATCHDOG_DEBUG" to a value of 1 to 4. This will overwrite the default debug level set above.


debugit()
    { # Output debug messages depending on how $debug_level is set.
      # first argument is the type of message. Must be one of the following:
      #    ERROR
      #    WARNING
      #    INFO
      #    DEBUG
      # Example: 
      #   debugit INFO "This is how you use the debug feature."
      # Example output:
      #   INFO: This is how you use the debug feature.

    case ${debug_level} in
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
            echo "Setting debug level to default of 3"
            debug_level=2
        ;;
    esac
    }

disp_help()
    { # Print script help to screen, and exit.
      # Optional argument will set exit value.
        echo -e "This is help."
        echo -e "usage: $0 {COMMAND} {OPTION} {ARGUMENTS}"
        echo -e "Commands:"
        echo -e "\tex\t- Example command"
        echo -e "Options:"
        echo -e "\t--opt_one|-o\t- Example option"
        echo -e "Argument\t- File name"
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
optspec="hv:-:"
while getopts "${optspec}" opt
    do
        case "${opt}" in
            -)
                case "${OPTARG}" in
                    xxxx)
                        opt_xxxx="${!OPTIND}"
                        (( OPTIND++ ))
                    ;;
                    xxxx=*)
                        opt_xxxx=${OPTARG#*=}
                    ;;
                    verbose)
                        debug_level="${!OPTIND}"
                        (( OPTIND++ ))
                        debugit DEBUG "debug_level set to '${debug_level}'"
                    ;;
                    verbose=*)
                        debug_level=${OPTARG#*=}
                        debugit DEBUG "debug_level set to '${debug_level}'"
                    ;;
                    v|vv|vvv|vvvv)
                        case "${OPTARG}" in
                            v)
                                debug_level=1
                            ;;
                            vv)
                                debug_level=2
                            ;;
                            vvv)
                                debug_level=3
                            ;;
                            vvvv)
                                debug_level=4
                            ;;
                        esac
                        debugit DEBUG "debug_level set to '${debug_level}'"
                    ;;
                    *)
                        if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                            echo "Unknown option --${OPTARG}" >&2
                        fi
                    ;;
                esac
            ;;
            v)
                case ${OPTARG} in
                    "0")
                        debug_level=0
                    ;;
                    "1")
                        debug_level=1
                    ;;
                    "2")
                        debug_level=2
                    ;;
                    "3")
                        debug_level=3
                    ;;
                    "4")
                        debug_level=4
                    ;;
                    "")
                        debug_level=1
                    ;;
                    v*)
                        case "${OPTARG}" in
                            v)
                                debug_level=2
                            ;;
                            vv)
                                debug_level=3
                            ;;
                            vvv)
                                debug_level=4
                            ;;
                            *)
                                >&2 echo "invalid debug level specified: 'v$(OPTARG)'"
                                disp_help 1
                            ;;
                        esac
                        debugit DEBUG "debug_level set to '${debug_level}'"
                    ;;
                    *)
                        >&2 echo "invalid debug level specified: '$(OPTARG)'"
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
if [ $# -gt 0 ]
    then
        debugit DEBUG "Parsing arguments"
        #Set argument variables here, like arg_file=$1
fi

# Read in relevant environment variables, and do the corresponding setup.

if [ -z "$SSL_WATCHDOG_DATADIR" ]
    then
        DATADIR="./"
    else
        DATADIR="$SSL_WATCHDOG_DATADIR"
fi
if [ ! -z $SSL_WATCHDOG_DEBUG ]
    then
        case $SSL_WATCHDOG_DEBUG in
            0)
                debug_level=0
                debugit DEBUG "debug_level set to '${debug_level}'"
            ;;
            1)
                debug_level=1 
                debugit DEBUG "debug_level set to '${debug_level}'"
            ;;
            2)
                debug_level=2 
                debugit DEBUG "debug_level set to '${debug_level}'"
            ;;
            3)
                debug_level=3 
                debugit DEBUG "debug_level set to '${debug_level}'"
            ;;
            4)
                debug_level=4 
                debugit DEBUG "debug_level set to '${debug_level}'"
            ;;
            *)
                debugit WARNING "Debug level SSL_WATCHDOG_DEBUG='$SSL_WATCHDOG_DEBUG' is invalid!\n\tPlease ensure this env var is empty, or set to a valid level of 1 to 4.\n"
            ;;
        esac
fi


# Helper functions
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
            debugit ERROR "INTERNAL ERROR - No server specified."
            debugit DEBUG "there don't seem to be any arguments remaining for 'server'. Have the following args: '$@'"
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
            debugit INFO "Using default keytool path '$JRE/bin/keytool'"
            tool="$JRE/bin/keytool"
        else
            debugit DEBUG "setting 'tool' to $1"
            tool=$1
            shift
    fi
    if [ $# -lt 1 ]
        then
            debugit DEBUG "there don't seem to be any arguments remaining for 'outfile'. Have the following args: '$@'"
            debugit INFO "Using default output path './${server}.cer'"
            outfile=./${server}.cer
        else
            debugit DEBUG "setting 'outfile' to $1"
            outfile=$1
            shift
    fi
    fi
        if [ $# -gt 0 ]
        then
            debugit ERROR "INTERNAL ERROR - Too many arguments to PullCert()."
            debugit DEBUG "Have the following args: '$@'"
    fi

    debugit INFO "Will pull cert from ${server}:${port}"
    ${keytool} -printcert -sslserver ${server}:${port} -rfc > ${outfile}
    if (( $! != 0 ))
        then
            debugit ERROR "Unable to reliably store certificate."
        else
            deugit INFO "Certificate stored here: ${outfile}"
            debugit DEBUG "$(cat ${outfile})"
    fi
    }