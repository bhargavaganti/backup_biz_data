#!/bin/bash
set -xv

ENV=$1

function error_exit()
{
ret_val=$1
process_step="${2}"
log_filename="${3}"
if [ $ret_val -ne 0 ]
then
echo -e "$(date '+%y%m%d %H:%M')\t Script errored at - ${process_step} step..."     ## >>${LOG_FILE}
exit -1
fi
}

pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd`
popd > /dev/null
export BIN_DIR=$SCRIPTPATH
export SQL_DIR=$SCRIPTPATH

SCRIPT_NAME=$(basename $0 .sh)
DATE_STR=`date '+%Y-%m-%d_%H%M%S'`
LOG_DIR=/tmp
LOG_FILE=${LOG_DIR}/${SCRIPT_NAME}.${DATE_STR}.out
starttime=`date`
#------------GLOBALS-----------
TARGET_DBNAME=biz_data_product_event
TARGET_DBNAME=apillai
THROTTLE_LIMIT=1
NUMBER_OF_DAYS2PROCESS=1
REPORT_SUITE_NAME=homerealtor
ROOT_FOLDER=s3://move-dataeng-omniture-${ENV}/${REPORT_SUITE_NAME}/${TARGET_DBNAME}
#------------------------------
# Dependency Check on Lookups
#------------------------------
process_step=DependencyCheck
LOOKUP_TABLENAME=${TARGET_DBNAME}.browser
lookup1_count=`python -u $BIN_DIR/get_record_count.py --tablename ${LOOKUP_TABLENAME} --env ${ENV}|grep ${LOOKUP_TABLENAME}|awk -F "," '{print $2}'`
LOOKUP_TABLENAME=${TARGET_DBNAME}.browser_type
lookup2_count=`python -u $BIN_DIR/get_record_count.py --tablename ${LOOKUP_TABLENAME} --env ${ENV}|grep ${LOOKUP_TABLENAME}|awk -F "," '{print $2}'`
LOOKUP_TABLENAME=${TARGET_DBNAME}.mobile_attributes
lookup3_count=`python -u $BIN_DIR/get_record_count.py --tablename ${LOOKUP_TABLENAME} --env ${ENV}|grep ${LOOKUP_TABLENAME}|awk -F "," '{print $2}'`
#lookup3_count=0
echo $lookup1_count
dependency_count=`echo "${lookup1_count} * ${lookup2_count} * ${lookup3_count} "|bc -l`
#exit 0
#------- Dependency Count Check - Count needs to be non-zero to proceed with ETL
ret_val=$dependency_count
if [ $ret_val -eq 0 ]
then
echo "dependency_count= ${dependency_count}"
echo -e "$(date '+%y%m%d %H:%M')\t Script errored at - ${process_step} step..."     ## >>${LOG_FILE}
exit -1
fi

#----------------------------------------
#---RDC Skinny Incremental:
#----------------------------------------
SQL_FILE=${SQL_DIR}/rdc_biz_data.sql
step=${SQL_FILE}
echo "-----------------------------------"
echo " Running $step ......"
echo "-----------------------------------"
SOURCE_TABLE=cnpd_omtr_pdt.hit_data
TARGET_TABLE=${TARGET_DBNAME}.rdc_biz_data
S3_TARGET_FOLDER_PARQUET_BASE=${ROOT_FOLDER}/rdc_biz_data
ETL_TYPE=pdt
ENV=${1}
time -p python -u ${BIN_DIR}/pe_ctas_wrapper.py --sql_file ${SQL_FILE} --source_table ${SOURCE_TABLE} --target_table ${TARGET_TABLE} --s3_target_folder_parquet_base ${S3_TARGET_FOLDER_PARQUET_BASE} --throttle_limit ${THROTTLE_LIMIT} --etl_type ${ETL_TYPE} --env ${ENV} --number_of_days2process=${NUMBER_OF_DAYS2PROCESS}

#--------------------------------------------
error_exit $? " ${SCRIPT_NAME}=> Job failed  " $LOG_FILE

exit 0
#----------------------------------------
#---RDC Summary Incremental:
#----------------------------------------
SQL_FILE=${SQL_DIR}/web_summary.sql
step=${SQL_FILE}
echo "-----------------------------------"
echo " Running $step ......"
echo "-----------------------------------"
SOURCE_TABLE=${TARGET_DBNAME}.rdc_biz_data
TARGET_TABLE=${TARGET_DBNAME}.web_summary
S3_TARGET_FOLDER_PARQUET_BASE=${ROOT_FOLDER}/web_summary
ETL_TYPE=summary
ENV=${1}
time -p python -u ${BIN_DIR}/pe_ctas_wrapper.py --sql_file ${SQL_FILE} --source_table ${SOURCE_TABLE} --target_table ${TARGET_TABLE} --s3_target_folder_parquet_base ${S3_TARGET_FOLDER_PARQUET_BASE} --throttle_limit ${THROTTLE_LIMIT} --etl_type ${ETL_TYPE} --env ${ENV} --number_of_days2process=${NUMBER_OF_DAYS2PROCESS}

#--------------------------------------
SQL_FILE=${SQL_DIR}/web_visit_summary.sql
step=${SQL_FILE}
echo "-----------------------------------"
echo " Running $step ......"
echo "-----------------------------------"
SOURCE_TABLE=${TARGET_DBNAME}.rdc_biz_data
TARGET_TABLE=${TARGET_DBNAME}.web_visit_summary
S3_TARGET_FOLDER_PARQUET_BASE=${ROOT_FOLDER}/web_visit_summary
ETL_TYPE=summary
ENV=${1}
time -p python -u ${BIN_DIR}/pe_ctas_wrapper.py --sql_file ${SQL_FILE} --source_table ${SOURCE_TABLE} --target_table ${TARGET_TABLE} --s3_target_folder_parquet_base ${S3_TARGET_FOLDER_PARQUET_BASE} --throttle_limit ${THROTTLE_LIMIT} --etl_type ${ETL_TYPE} --env ${ENV} --number_of_days2process=${NUMBER_OF_DAYS2PROCESS}
#--------------------------------------------
#error_exit $? " ${SCRIPT_NAME}=> Job failed  " $LOG_FILE


echo "Finished Running Job"
endtime=`date`
echo "------------------<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>-------------------------" 
echo "---------------@ Process Started ---  at  $starttime " 
echo "---------------@ Process Completed --- at $endtime"
echo "------------------<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>-------------------------" 
