#!/usr/bin/env python3

import connexion
from flask_cors import CORS

if __name__ == '__main__':
    app = connexion.App(__name__, specification_dir='./swagger/')
    app.add_api('swagger.yaml', arguments={'title': '[Proteomics eXpression Interface](https://github.com/HUPO-PSI/proxi-schemas/)'})
    CORS(app.app)
    app.run(port=5050, threaded=True)
