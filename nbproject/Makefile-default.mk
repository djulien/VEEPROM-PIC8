#
# Generated Makefile - do not edit!
#
# Edit the Makefile in the project folder instead (../Makefile). Each target
# has a -pre and a -post target defined where you can add customized code.
#
# This makefile implements configuration specific macros and targets.


# Include project Makefile
ifeq "${IGNORE_LOCAL}" "TRUE"
# do not include local makefile. User is passing all local related variables already
else
include Makefile
# Include makefile containing local settings
ifeq "$(wildcard nbproject/Makefile-local-default.mk)" "nbproject/Makefile-local-default.mk"
include nbproject/Makefile-local-default.mk
endif
endif

# Environment
MKDIR=mkdir -p
RM=rm -f 
MV=mv 
CP=cp 

# Macros
CND_CONF=default
ifeq ($(TYPE_IMAGE), DEBUG_RUN)
IMAGE_TYPE=debug
OUTPUT_SUFFIX=cof
DEBUGGABLE_SUFFIX=cof
FINAL_IMAGE=dist/${CND_CONF}/${IMAGE_TYPE}/VEEPROM-PIC8.X.${IMAGE_TYPE}.${OUTPUT_SUFFIX}
else
IMAGE_TYPE=production
OUTPUT_SUFFIX=hex
DEBUGGABLE_SUFFIX=cof
FINAL_IMAGE=dist/${CND_CONF}/${IMAGE_TYPE}/VEEPROM-PIC8.X.${IMAGE_TYPE}.${OUTPUT_SUFFIX}
endif

ifeq ($(COMPARE_BUILD), true)
COMPARISON_BUILD=
else
COMPARISON_BUILD=
endif

ifdef SUB_IMAGE_ADDRESS

else
SUB_IMAGE_ADDRESS_COMMAND=
endif

# Object Directory
OBJECTDIR=build/${CND_CONF}/${IMAGE_TYPE}

# Distribution Directory
DISTDIR=dist/${CND_CONF}/${IMAGE_TYPE}

# Source Files Quoted if spaced
SOURCEFILES_QUOTED_IF_SPACED=veeprom-pic8.asm

# Object Files Quoted if spaced
OBJECTFILES_QUOTED_IF_SPACED=${OBJECTDIR}/veeprom-pic8.o
POSSIBLE_DEPFILES=${OBJECTDIR}/veeprom-pic8.o.d

# Object Files
OBJECTFILES=${OBJECTDIR}/veeprom-pic8.o

# Source Files
SOURCEFILES=veeprom-pic8.asm



CFLAGS=
ASFLAGS=
LDLIBSOPTIONS=

############# Tool locations ##########################################
# If you copy a project from one host to another, the path where the  #
# compiler is installed may be different.                             #
# If you open this project with MPLAB X in the new host, this         #
# makefile will be regenerated and the paths will be corrected.       #
#######################################################################
# fixDeps replaces a bunch of sed/cat/printf statements that slow down the build
FIXDEPS=fixDeps

# The following macros may be used in the pre and post step lines
Device=PIC16F15313
ProjectDir=/home/dj/MPLABXProjects/VEEPROM-PIC8.X
ProjectName=veeprom-pic8
ConfName=default
ImagePath=dist/default/${IMAGE_TYPE}/VEEPROM-PIC8.X.${IMAGE_TYPE}.${OUTPUT_SUFFIX}
ImageDir=dist/default/${IMAGE_TYPE}
ImageName=VEEPROM-PIC8.X.${IMAGE_TYPE}.${OUTPUT_SUFFIX}
ifeq ($(TYPE_IMAGE), DEBUG_RUN)
IsDebug="true"
else
IsDebug="false"
endif

.build-conf:  .pre ${BUILD_SUBPROJECTS}
ifneq ($(INFORMATION_MESSAGE), )
	@echo $(INFORMATION_MESSAGE)
endif
	${MAKE}  -f nbproject/Makefile-default.mk dist/${CND_CONF}/${IMAGE_TYPE}/VEEPROM-PIC8.X.${IMAGE_TYPE}.${OUTPUT_SUFFIX}
	@echo "--------------------------------------"
	@echo "User defined post-build step: [rm -f nope__FILE__* && cp ${ImagePath}  ${ProjectDir} && cp ${ImagePath} /home/dj/Documents/ESOL-fog/ESOL22/tools/PIC/firmware &&  awk 'BEGIN{IGNORECASE=1} NR==FNR { if ($$2 == "EQU") EQU[$$1] = $$3; next; } !/^ +((M|[0-9]+) +)?(EXPAND|EXITM|LIST)([ ;_]|$$)/  { if ((NF != 2) || !match($$2, /^[0-9A-Fa-f]+$$/) || (!EQU[$$1] && !match($$1, /_[0-9]+$$/))) print; }'  /opt/microchip/mplabx/v5.35/mpasmx/p16f15313.inc  ./build/${ConfName}/${IMAGE_TYPE}/${ProjectName}.o.lst  >  ${ProjectName}.LST]"
	@rm -f nope__FILE__* && cp ${ImagePath}  ${ProjectDir} && cp ${ImagePath} /home/dj/Documents/ESOL-fog/ESOL22/tools/PIC/firmware &&  awk 'BEGIN{IGNORECASE=1} NR==FNR { if ($$2 == "EQU") EQU[$$1] = $$3; next; } !/^ +((M|[0-9]+) +)?(EXPAND|EXITM|LIST)([ ;_]|$$)/  { if ((NF != 2) || !match($$2, /^[0-9A-Fa-f]+$$/) || (!EQU[$$1] && !match($$1, /_[0-9]+$$/))) print; }'  /opt/microchip/mplabx/v5.35/mpasmx/p16f15313.inc  ./build/${ConfName}/${IMAGE_TYPE}/${ProjectName}.o.lst  >  ${ProjectName}.LST
	@echo "--------------------------------------"

MP_PROCESSOR_OPTION=16f15313
MP_LINKER_DEBUG_OPTION= 
# ------------------------------------------------------------------------------------
# Rules for buildStep: assemble
ifeq ($(TYPE_IMAGE), DEBUG_RUN)
${OBJECTDIR}/veeprom-pic8.o: veeprom-pic8.asm  nbproject/Makefile-${CND_CONF}.mk
	@${MKDIR} "${OBJECTDIR}" 
	@${RM} ${OBJECTDIR}/veeprom-pic8.o.d 
	@${RM} ${OBJECTDIR}/veeprom-pic8.o 
	@${FIXDEPS} dummy.d -e "/home/dj/MPLABXProjects/VEEPROM-PIC8.X/veeprom-pic8.ERR" $(SILENT) -c ${MP_AS} $(MP_EXTRA_AS_PRE) -d__DEBUG -d__MPLAB_DEBUGGER_SIMULATOR=1 -q -p$(MP_PROCESSOR_OPTION) -u  $(ASM_OPTIONS)    \\\"/home/dj/MPLABXProjects/VEEPROM-PIC8.X/veeprom-pic8.asm\\\" 
	@${MV}  /home/dj/MPLABXProjects/VEEPROM-PIC8.X/veeprom-pic8.O ${OBJECTDIR}/veeprom-pic8.o
	@${MV}  /home/dj/MPLABXProjects/VEEPROM-PIC8.X/veeprom-pic8.ERR ${OBJECTDIR}/veeprom-pic8.o.err
	@${MV}  /home/dj/MPLABXProjects/VEEPROM-PIC8.X/veeprom-pic8.LST ${OBJECTDIR}/veeprom-pic8.o.lst
	@${RM}  /home/dj/MPLABXProjects/VEEPROM-PIC8.X/veeprom-pic8.HEX 
	@${DEP_GEN} -d "${OBJECTDIR}/veeprom-pic8.o"
	@${FIXDEPS} "${OBJECTDIR}/veeprom-pic8.o.d" $(SILENT) -rsi ${MP_AS_DIR} -c18 
	
else
${OBJECTDIR}/veeprom-pic8.o: veeprom-pic8.asm  nbproject/Makefile-${CND_CONF}.mk
	@${MKDIR} "${OBJECTDIR}" 
	@${RM} ${OBJECTDIR}/veeprom-pic8.o.d 
	@${RM} ${OBJECTDIR}/veeprom-pic8.o 
	@${FIXDEPS} dummy.d -e "/home/dj/MPLABXProjects/VEEPROM-PIC8.X/veeprom-pic8.ERR" $(SILENT) -c ${MP_AS} $(MP_EXTRA_AS_PRE) -q -p$(MP_PROCESSOR_OPTION) -u  $(ASM_OPTIONS)    \\\"/home/dj/MPLABXProjects/VEEPROM-PIC8.X/veeprom-pic8.asm\\\" 
	@${MV}  /home/dj/MPLABXProjects/VEEPROM-PIC8.X/veeprom-pic8.O ${OBJECTDIR}/veeprom-pic8.o
	@${MV}  /home/dj/MPLABXProjects/VEEPROM-PIC8.X/veeprom-pic8.ERR ${OBJECTDIR}/veeprom-pic8.o.err
	@${MV}  /home/dj/MPLABXProjects/VEEPROM-PIC8.X/veeprom-pic8.LST ${OBJECTDIR}/veeprom-pic8.o.lst
	@${RM}  /home/dj/MPLABXProjects/VEEPROM-PIC8.X/veeprom-pic8.HEX 
	@${DEP_GEN} -d "${OBJECTDIR}/veeprom-pic8.o"
	@${FIXDEPS} "${OBJECTDIR}/veeprom-pic8.o.d" $(SILENT) -rsi ${MP_AS_DIR} -c18 
	
endif

# ------------------------------------------------------------------------------------
# Rules for buildStep: link
ifeq ($(TYPE_IMAGE), DEBUG_RUN)
dist/${CND_CONF}/${IMAGE_TYPE}/VEEPROM-PIC8.X.${IMAGE_TYPE}.${OUTPUT_SUFFIX}: ${OBJECTFILES}  nbproject/Makefile-${CND_CONF}.mk    
	@${MKDIR} dist/${CND_CONF}/${IMAGE_TYPE} 
	${MP_LD} $(MP_EXTRA_LD_PRE)   -p$(MP_PROCESSOR_OPTION)  -w -x -u_DEBUG -z__ICD2RAM=1 -m"${DISTDIR}/${PROJECTNAME}.${IMAGE_TYPE}.map"   -z__MPLAB_BUILD=1  -z__MPLAB_DEBUG=1 -z__MPLAB_DEBUGGER_SIMULATOR=1 $(MP_LINKER_DEBUG_OPTION) -odist/${CND_CONF}/${IMAGE_TYPE}/VEEPROM-PIC8.X.${IMAGE_TYPE}.${OUTPUT_SUFFIX}  ${OBJECTFILES_QUOTED_IF_SPACED}     
else
dist/${CND_CONF}/${IMAGE_TYPE}/VEEPROM-PIC8.X.${IMAGE_TYPE}.${OUTPUT_SUFFIX}: ${OBJECTFILES}  nbproject/Makefile-${CND_CONF}.mk   
	@${MKDIR} dist/${CND_CONF}/${IMAGE_TYPE} 
	${MP_LD} $(MP_EXTRA_LD_PRE)   -p$(MP_PROCESSOR_OPTION)  -w  -m"${DISTDIR}/${PROJECTNAME}.${IMAGE_TYPE}.map"   -z__MPLAB_BUILD=1  -odist/${CND_CONF}/${IMAGE_TYPE}/VEEPROM-PIC8.X.${IMAGE_TYPE}.${DEBUGGABLE_SUFFIX}  ${OBJECTFILES_QUOTED_IF_SPACED}     
endif

.pre:
	@echo "--------------------------------------"
	@echo "User defined pre-build step: [cat ${ProjectName}.asm  |  awk '{gsub(/__LINE__/, NR)}1' |  tee  "__FILE__ 1.ASM"  "__FILE__ 2.ASM"  "__FILE__ 3.ASM"  "__FILE__ 4.ASM"  "__FILE__ 5.ASM"  "__FILE__ 6.ASM"  "__FILE__ 7.ASM"  >  __FILE__.ASM ]"
	@cat ${ProjectName}.asm  |  awk '{gsub(/__LINE__/, NR)}1' |  tee  "__FILE__ 1.ASM"  "__FILE__ 2.ASM"  "__FILE__ 3.ASM"  "__FILE__ 4.ASM"  "__FILE__ 5.ASM"  "__FILE__ 6.ASM"  "__FILE__ 7.ASM"  >  __FILE__.ASM 
	@echo "--------------------------------------"

# Subprojects
.build-subprojects:


# Subprojects
.clean-subprojects:

# Clean Targets
.clean-conf: ${CLEAN_SUBPROJECTS}
	${RM} -r build/default
	${RM} -r dist/default

# Enable dependency checking
.dep.inc: .depcheck-impl

DEPFILES=$(shell "${PATH_TO_IDE_BIN}"mplabwildcard ${POSSIBLE_DEPFILES})
ifneq (${DEPFILES},)
include ${DEPFILES}
endif
