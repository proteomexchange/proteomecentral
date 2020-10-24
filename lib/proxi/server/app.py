#!/usr/bin/env python3

import connexion

if __name__ == '__main__':
    app = connexion.App(__name__, specification_dir='./swagger/')
    app.add_api('swagger.yaml', arguments={'title': '[Proteomics eXpression Interface](https://github.com/HUPO-PSI/proxi-schemas/)'})
    app.run(port=8080)
