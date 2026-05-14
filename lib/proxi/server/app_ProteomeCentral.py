#!/usr/bin/env python3

import os
import sys
import connexion
from flask_cors import CORS

if __name__ == '__main__':

    proxi_port = os.environ['PROXI_PORT']
    if not proxi_port:
        print("ERROR: Environment variable PROXI_PORT must be set")
        exit()

    proxi_instance = os.environ['PROXI_INSTANCE']
    if not proxi_instance:
        print("ERROR: Environment variable PROXI_INSTANCE must be set")
        exit()

    sys.path.append(f"/net/dblocal/data/SpectralLibraries/python/{proxi_instance}/SpectralLibraries/lib")

    app = connexion.App(__name__, specification_dir='./swagger/')
    app.add_api('swagger.yaml', arguments={'title': '[Proteomics eXpression Interface](https://github.com/HUPO-PSI/proxi-schemas/)'})
    CORS(app.app)
    app.run(port=proxi_port, threaded=True)
