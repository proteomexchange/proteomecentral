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


class Peptidoform(object):
    """
    NOTE: This class is auto generated by the swagger code generator program.
    Do not edit the class manually.
    """
    def __init__(self, peptidoform=None, peptide_sequence=None, count_psm=None, count_datasets=None, ptms=None, protein_accessions=None):
        """
        Peptidoform - a model defined in Swagger

        :param dict swaggerTypes: The key is attribute name
                                  and the value is attribute type.
        :param dict attributeMap: The key is attribute name
                                  and the value is json key in definition.
        """
        self.swagger_types = {
            'peptidoform': 'str',
            'peptide_sequence': 'str',
            'count_psm': 'int',
            'count_datasets': 'str',
            'ptms': 'list[Modification]',
            'protein_accessions': 'list[ProteinIdentification]'
        }

        self.attribute_map = {
            'peptidoform': 'peptidoform',
            'peptide_sequence': 'peptideSequence',
            'count_psm': 'countPSM',
            'count_datasets': 'countDatasets',
            'ptms': 'ptms',
            'protein_accessions': 'proteinAccessions'
        }

        self._peptidoform = peptidoform
        self._peptide_sequence = peptide_sequence
        self._count_psm = count_psm
        self._count_datasets = count_datasets
        self._ptms = ptms
        self._protein_accessions = protein_accessions

    @property
    def peptidoform(self):
        """
        Gets the peptidoform of this Peptidoform.
        Peptidoform as String

        :return: The peptidoform of this Peptidoform.
        :rtype: str
        """
        return self._peptidoform

    @peptidoform.setter
    def peptidoform(self, peptidoform):
        """
        Sets the peptidoform of this Peptidoform.
        Peptidoform as String

        :param peptidoform: The peptidoform of this Peptidoform.
        :type: str
        """

        self._peptidoform = peptidoform

    @property
    def peptide_sequence(self):
        """
        Gets the peptide_sequence of this Peptidoform.
        Peptide Sequence

        :return: The peptide_sequence of this Peptidoform.
        :rtype: str
        """
        return self._peptide_sequence

    @peptide_sequence.setter
    def peptide_sequence(self, peptide_sequence):
        """
        Sets the peptide_sequence of this Peptidoform.
        Peptide Sequence

        :param peptide_sequence: The peptide_sequence of this Peptidoform.
        :type: str
        """

        self._peptide_sequence = peptide_sequence

    @property
    def count_psm(self):
        """
        Gets the count_psm of this Peptidoform.
        Number of PSMs that support the current Peptidoform

        :return: The count_psm of this Peptidoform.
        :rtype: int
        """
        return self._count_psm

    @count_psm.setter
    def count_psm(self, count_psm):
        """
        Sets the count_psm of this Peptidoform.
        Number of PSMs that support the current Peptidoform

        :param count_psm: The count_psm of this Peptidoform.
        :type: int
        """

        self._count_psm = count_psm

    @property
    def count_datasets(self):
        """
        Gets the count_datasets of this Peptidoform.
        Number of datasets that support the current Peptidoform

        :return: The count_datasets of this Peptidoform.
        :rtype: str
        """
        return self._count_datasets

    @count_datasets.setter
    def count_datasets(self, count_datasets):
        """
        Sets the count_datasets of this Peptidoform.
        Number of datasets that support the current Peptidoform

        :param count_datasets: The count_datasets of this Peptidoform.
        :type: str
        """

        self._count_datasets = count_datasets

    @property
    def ptms(self):
        """
        Gets the ptms of this Peptidoform.


        :return: The ptms of this Peptidoform.
        :rtype: list[Modification]
        """
        return self._ptms

    @ptms.setter
    def ptms(self, ptms):
        """
        Sets the ptms of this Peptidoform.


        :param ptms: The ptms of this Peptidoform.
        :type: list[Modification]
        """

        self._ptms = ptms

    @property
    def protein_accessions(self):
        """
        Gets the protein_accessions of this Peptidoform.


        :return: The protein_accessions of this Peptidoform.
        :rtype: list[ProteinIdentification]
        """
        return self._protein_accessions

    @protein_accessions.setter
    def protein_accessions(self, protein_accessions):
        """
        Sets the protein_accessions of this Peptidoform.


        :param protein_accessions: The protein_accessions of this Peptidoform.
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
