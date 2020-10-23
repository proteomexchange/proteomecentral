#!/bin/bash

export RESOURCE=ProteomeCentral
export DEVAREA=production

LOGFILE=PROXI_${RESOURCE}_${DEVAREA}.log
ELOGFILE=PROXI_${RESOURCE}_${DEVAREA}.elog

if [ -e $LOGFILE ]
then
    /bin/rm $LOGFILE
fi

if [ -e $ELOGFILE ]
then
    /bin/rm $ELOGFILE
fi

export PATH=/net/dblocal/src/python/python3/bin:$PATH

exec python3 app_ProteomeCentral_${DEVAREA}.py 1>$LOGFILE 2>$ELOGFILE

