#!/bin/csh

echo "Updating controlled vocabularies for ProteomeXchange"
date
echo " "

echo " "
echo "Update PSI MS CV from GitHub"
cd /net/dblocal/wwwspecial/proteomecentral/extern/PSI-MS/GitHub/psi-ms-CV
git pull

echo " "
echo "Update PRIDE CV from GitHub"
cd /net/dblocal/wwwspecial/proteomecentral/extern/PRIDE/pride-ontology
git pull

echo " "
echo "Update PSI MOD CV from SourceForge"
cd /net/dblocal/wwwspecial/proteomecentral/extern/PSI-MOD/psi-mod-CV
git pull

echo " "
echo "Update Unimod via wget URL"
cd /net/dblocal/wwwspecial/proteomecentral/extern/Unimod
wget -N 'http://www.unimod.org/obo/unimod.obo'

echo " "
echo "Update PTMList via wget URL"
cd /net/dblocal/wwwspecial/proteomecentral/extern/PTMList
wget -N 'http://www.uniprot.org/docs/ptmlist.txt'

