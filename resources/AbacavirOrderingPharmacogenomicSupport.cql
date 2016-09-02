library AbacavirOrderingPharmacogenomicSupport version '1'

using FHIR version '1.6'

include FHIRHelpers version '1.6' called FHIRHelpers

/*

For each order of abacavir for a patient

  Select all records from the patient's records that contain the LOINC observation code: 50956-2^HLA-B*57:01^LN

    If no records are found
      Trigger an intervention in the form of a alert (CommunicationRequest) with the following two parts:
        1. A high level concise description of the issue in a format similar to a drug allergy or interaction alert
        2. A more detailed textual description potentially based on the 2014 CPIC guidelines:
          "A HLA-B*57:01 genotype test is recommended before prescribing abacavir per the FDA's black box warning
          regarding the risk of serious hypersensitivity reactions in patients that carry this allele. A HLA-B*57:01
          genotype test does not appear to have been ordered for this patient. Please do the following to order the
          HLA-B*57:01 genotype test <<insert dialogue boxes here to order clinical HLA-B test>>"

    Else if the records contain conflicting statuses - one “10828004^Positive^SCT” the other “260385009^Negative^SCT”
      Trigger an intervention in the form of an alert with the following textual description:
        "There are two conflicting results for this patient. Consult with a clinical pharmacist or laboratory
        professional to resolve the conflict."  TODO: Should we enable this consult in the CQL?

    Else if any of the records contain the status “10828004^Positive^SCT”
      Trigger an intervention in the form of an alert with the following textual description
      (formatted in a manner that is consistent with a drug allergy or interaction alert):
        "The HLA-B*57:01 allele is present in this patient. This allele is associated with high risk of severe
        hypersensitivity to abacavir. HLA-B*57:01 positive patients should NOT be prescribed abacavir. Please
        choose an alternate antiretroviral. For more information, please consult a <<recommended clinical
        professional for consultation, for example some institutions might direct to a clinical pharmacist>>."
        NOTE: If the CDS capability exists, the clinician should be presented a list of acceptable alternative
              drugs to simplify the proper replacement of the order.

*/

codesystem LOINC: 'http://loinc.org'
codesystem SNOMED: 'http://snomed.org/sct'
codesystem DiagnosticPriority: 'http://hl7.org/fhir/diagnostic-order-priority'
codesystem RequestStage: 'http://hl7.org/fhir/request-stage'

context Patient

define "Needs Genotype Test":
  not exists ("Observed HLA-B*57:01 Allele")

define "Should Notify User of Conflicting Results":
  exists ("Negative Status for Hypersensitivity")
    and exists ("Positive Status for Hypersensitivity")

define "Should Notify User of Patient's Hypersensitivity":
  exists ("Positive Status for Hypersensitivity")
    and not exists ("Negative Status for Hypersensitivity")

define "Genotype Results for HLA-B*57:01 Allele":
    Code '50956-2' from LOINC display 'HLA-B*57:01[Presence]'

define "Observed HLA-B*57:01 Allele":
  [Observation: "Genotype Results for HLA-B*57:01 Allele"]

define "Positive Status for Hypersensitivity":
  "Observed HLA-B*57:01 Allele" A
    where A.valueCodeableConcept ~ ToConcept(Code '10828004' from SNOMED display 'Positive')

define "Negative Status for Hypersensitivity":
  "Observed HLA-B*57:01 Allele" A
    where A.valueCodeableConcept ~ ToConcept(Code '260385009' from SNOMED display 'Negative')

// These are now represented as ActivityDefinitions in the decision support rules (PlanDefinition resources)
// The definitions are preserved here for reference.

/*
define "Create Diagnostic Order for Genotype Test":
  DiagnosticRequest {
    stage: FHIR.CodeableConcept { coding: { FHIR.Coding { system: FHIR.uri { value: 'http://fhir.org/request-stage' }, code: FHIR.code { value: 'proposal' } } } },
    //stage: Code 'proposal' from RequestStage display 'Proposal',
    code: "Genotype Results for HLA-B*57:01 Allele",
    // Priority element seems to have been removed in STU3?
    // Is this important for this use case?
    //priority: Code 'urgent' from DiagnosticPriority display 'Urgent',
    subject: FHIR.Reference { reference: FHIR.uri { value: 'Patient/' + Patient.id } },
    // subject: Patient
    //context: Encounter,
    occurrenceDateTime: Now(),
    requester: "CDS System"
    //orderer: Practitioner,
    reason: CodeableConcept { text: 'The patient is being prescribed Abacavir without appropriate genotype testing for Abacavir sensitivity.'}
    supportingInformation: "Observed HLA-B*57:01 Allele" O return FHIR.Reference { reference: FHIR.uri { value: 'Observation/' + O.id } },
  }

define "Missing Genotype Test Alert":
  CommunicationRequest {
    sender: "CDS System",
    recipient: "Primary Provider",
    payload: {
      Tuple { content: 'An order for Abacavir has been made for the patient without proper genotype screening'},
      Tuple {
        content: 'An HLA-B*57:01 genotype test is recommended before prescribing abacavir per the FDA\'s black box warning
        regarding the risk of serious hypersensitivity reactions in patients that carry this allele. A HLA-B*57:01
        genotype test does not appear to have been ordered for this patient. An unsigned order has been created to perform
        this test, <<click here to sign the order>>'
      },
      Tuple { content: "Create Genotype Test" }
    },
    status: 'proposed',
    encounter: Encounter,
    scheduled: Now(),
    reason: "Needs Genotype Test",
    requestedOn: Now(),
    subject: Patient,
    priority: Code 'urgent' from DiagnosticPriority display 'Urgent'
  }

define "Conflicting Test Results Alert":
  CommunicationRequest {
    sender: "CDS System",
    recipient: "Primary Provider",
    payload: {
      Tuple {
        content: 'There are two conflicting results for this patient. Consult with a clinical pharmacist or laboratory
        professional to resolve the conflict.'
        },
      Tuple { content: "Conflicting Genotype Test Results" }
    },
    status: 'proposed',
    encounter: Encounter,
    scheduled: Now(),
    reason: "Conflicting Genotype Test Results",
    requestedOn: Now(),
    subject: Patient,
    priority: Code 'routine' from DiagnosticPriority display 'Routine'
  }

define "Hypersensitivity To Abacavir Alert":
  CommunicationRequest {
    sender: "CDS System",
    recipient: "Primary Provider",
    payload: {
      Tuple {
        content: 'The HLA-B*57:01 allele is present in this patient. This allele is associated with high risk of severe
        hypersensitivity to abacavir. HLA-B*57:01 positive patients should NOT be prescribed abacavir. Please
        choose an alternate antiretroviral. For more information, please consult a <<recommended clinical
        professional for consultation, for example some institutions might direct to a clinical pharmacist>>.'
        },
      Tuple { content: "Hypersensitivity To Abacavir Detected" }
    },
    status: 'proposed',
    encounter: Encounter,
    scheduled: Now(),
    reason: "Genotype Test Results Positive For HLA-B*57:01 Allele",
    requestedOn: Now(),
    subject: Patient,
    priority: Code 'urgent' from DiagnosticPriority display 'Urgent'
  }
*/
