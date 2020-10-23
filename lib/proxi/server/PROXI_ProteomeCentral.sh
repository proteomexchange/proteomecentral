#!/bin/bash

export RESOURCE=ProteomeCentral
export DEVAREA=test

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

cd /net/dblocal/wwwspecial/proteomecentral/devED/lib/proxi/server

export PATH=/net/dblocal/src/python/python3/bin:$PATH

exec python3 app_ProteomeCentral.py 1>$LOGFILE 2>$ELOGFILE

