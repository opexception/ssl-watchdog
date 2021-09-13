#!/usr/bin/env bash

# Scan for certificates on a given URL, catalog any certs found along with their expiration times.
# Compate the results of the current run with saves results froma previous run to check for changes.
# Give warning on epiry time, or certificate changes.
#
# Author: Robert.Maracle
#  

###############################################################################
## Initialize some variables
###############################################################################
HOSTNAME=$(uname -n)

# Remove the first ".", and everything after it from $HOSTNAME
SHORT_NAME=${HOSTNAME%%.*} 

 # Remove the first ".", and everything before it from $HOSTNAME
FULL_DOMAIN=${HOSTNAME#*.}

# Remove the first ".", and everything after it from $FULL_DOMAIN
DOMAIN=${FULL_DOMAIN%%.*} 

# Get a timestamp in UTC to avoid timezone conversion per region
NOW=$(date --utc +%s)


# use the "-x" argument to set debugging.
# Initial debug level. Will be overwritten by "-x" argument, once it has been parsed.
#debug_level=0 # Silent. No additional debug output at all
#debug_level=1 # Write only ERRORs to stderr
#debug_level=2 # Write ERRORs to stderr, and WARNINGs to stdout
#debug_level=3 # Write ERRORs to stderr, WARNINGs and INFOs to stdout
debug_level=4 # Write ERRORs to stderr, WARNINGs, INFOs, and DEBUGs to stdout

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
