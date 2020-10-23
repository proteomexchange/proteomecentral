# coding: utf-8

"""
    Proteomics Expression Interface

    [Proteomics eXpression Interface](https://github.com/HUPO-PSI/proxi-schemas/)

    OpenAPI spec version: 0.1.1
    Contact: yperez@ebi.ac.uk
    Generated by: https://github.com/swagger-api/swagger-codegen.git

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
"""

from pprint import pformat
from six import iteritems
import re


class Psm(object):
    """
    NOTE: This class is auto generated by the swagger code generator program.
    Do not edit the class manually.
    """
    def __init__(self, accession=None, usi=None, peptide_sequence=None, ptms=None, search_engine_score=None, retention_time=None, charge=None, protein_accessions=None):
        """
        Psm - a model defined in Swagger

        :param dict swaggerTypes: The key is attribute name
                                  and the value is attribute type.
        :param dict attributeMap: The key is attribute name
                                  and the value is json key in definition.
        """
        self.swagger_types = {
            'accession': 'str',
            'usi': 'str',
            'peptide_sequence': 'str',
            'ptms': 'list[Modification]',
            'search_engine_score': 'list[OntologyTerm]',
            'retention_time': 'float',
            'charge': 'int',
            'protein_accessions': 'list[ProteinIdentification]'
        }

        self.attribute_map = {
            'accession': 'accession',
            'usi': 'usi',
            'peptide_sequence': 'peptideSequence',
            'ptms': 'ptms',
            'search_engine_score': 'searchEngineScore',
            'retention_time': 'retentionTime',
            'charge': 'charge',
            'protein_accessions': 'proteinAccessions'
        }

        self._accession = accession
        self._usi = usi
        self._peptide_sequence = peptide_sequence
        self._ptms = ptms
        self._search_engine_score = search_engine_score
        self._retention_time = retention_time
        self._charge = charge
        self._protein_accessions = protein_accessions

    @property
    def accession(self):
        """
        Gets the accession of this Psm.
        Accession of the PSM

        :return: The accession of this Psm.
        :rtype: str
        """
        return self._accession

    @accession.setter
    def accession(self, accession):
        """
        Sets the accession of this Psm.
        Accession of the PSM

        :param accession: The accession of this Psm.
        :type: str
        """

        self._accession = accession

    @property
    def usi(self):
        """
        Gets the usi of this Psm.
        The USI representation for the PSM

        :return: The usi of this Psm.
        :rtype: str
        """
        return self._usi

    @usi.setter
    def usi(self, usi):
        """
        Sets the usi of this Psm.
        The USI representation for the PSM

        :param usi: The usi of this Psm.
        :type: str
        """

        self._usi = usi

    @property
    def peptide_sequence(self):
        """
        Gets the peptide_sequence of this Psm.
        Peptide sequence

        :return: The peptide_sequence of this Psm.
        :rtype: str
        """
        return self._peptide_sequence

    @peptide_sequence.setter
    def peptide_sequence(self, peptide_sequence):
        """
        Sets the peptide_sequence of this Psm.
        Peptide sequence

        :param peptide_sequence: The peptide_sequence of this Psm.
        :type: str
        """

        self._peptide_sequence = peptide_sequence

    @property
    def ptms(self):
        """
        Gets the ptms of this Psm.


        :return: The ptms of this Psm.
        :rtype: list[Modification]
        """
        return self._ptms

    @ptms.setter
    def ptms(self, ptms):
        """
        Sets the ptms of this Psm.


        :param ptms: The ptms of this Psm.
        :type: list[Modification]
        """

        self._ptms = ptms

    @property
    def search_engine_score(self):
        """
        Gets the search_engine_score of this Psm.


        :return: The search_engine_score of this Psm.
        :rtype: list[OntologyTerm]
        """
        return self._search_engine_score

    @search_engine_score.setter
    def search_engine_score(self, search_engine_score):
        """
        Sets the search_engine_score of this Psm.


        :param search_engine_score: The search_engine_score of this Psm.
        :type: list[OntologyTerm]
        """

        self._search_engine_score = search_engine_score

    @property
    def retention_time(self):
        """
        Gets the retention_time of this Psm.
        precursor retention time

        :return: The retention_time of this Psm.
        :rtype: float
        """
        return self._retention_time

    @retention_time.setter
    def retention_time(self, retention_time):
        """
        Sets the retention_time of this Psm.
        precursor retention time

        :param retention_time: The retention_time of this Psm.
        :type: float
        """

        self._retention_time = retention_time

    @property
    def charge(self):
        """
        Gets the charge of this Psm.
        precursor charge

        :return: The charge of this Psm.
        :rtype: int
        """
        return self._charge

    @charge.setter
    def charge(self, charge):
        """
        Sets the charge of this Psm.
        precursor charge

        :param charge: The charge of this Psm.
        :type: int
        """

        self._charge = charge

    @property
    def protein_accessions(self):
        """
        Gets the protein_accessions of this Psm.


        :return: The protein_accessions of this Psm.
        :rtype: list[ProteinIdentification]
        """
        return self._protein_accessions

    @protein_accessions.setter
    def protein_accessions(self, protein_accessions):
        """
        Sets the protein_accessions of this Psm.


        :param protein_accessions: The protein_accessions of this Psm.
        :type: list[ProteinIdentification]
        """

        self._protein_accessions = protein_accessions

    def to_dict(self):
        """
        Returns the model properties as a dict
        """
        result = {}

        for attr, _ in iteritems(self.swagger_types):
            value = getattr(self, attr)
            if isinstance(value, list):
                result[attr] = list(map(
                    lambda x: x.to_dict() if hasattr(x, "to_dict") else x,
                    value
                ))
            elif hasattr(value, "to_dict"):
                result[attr] = value.to_dict()
            elif isinstance(value, dict):
                result[attr] = dict(map(
                    lambda item: (item[0], item[1].to_dict())
                    if hasattr(item[1], "to_dict") else item,
                    value.items()
                ))
            else:
                result[attr] = value

        return result

    def to_str(self):
        """
        Returns the string representation of the model
        """
        return pformat(self.to_dict())

    def __repr__(self):
        """
        For `print` and `pprint`
        """
        return self.to_str()

    def __eq__(self, other):
        """
        Returns true if both objects are equal
        """
        return self.__dict__ == other.__dict__

    def __ne__(self, other):
        """
        Returns true if both objects are not equal
        """
        return not self == other
