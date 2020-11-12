#!/bin/bash

LOGFILE=PROXI_${RESOURCE}_${PROXI_INSTANCE}.log
ELOGFILE=PROXI_${RESOURCE}_${PROXI_INSTANCE}.elog

if [ -e $LOGFILE ]
then
    /bin/rm $LOGFILE
fi

if [ -e $ELOGFILE ]
then
    /bin/rm $ELOGFILE
fi

export PATH=/net/dblocal/src/python/python3/bin:$PATH

exec python3 app_${RESOURCE}_${PROXI_INSTANCE}.py 1>$LOGFILE 2>$ELOGFILE

