import ballerina/ai;

// Eight clinical protocol documents, one per department, containing the department name,
// the protocol name, the clinical indicators it covers, and the recommended appointment type.
final ai:TextDocument[] clinicalProtocolDocuments = [
    {
        content: string `## Cardiology

**Protocol Name:** Acute Cardiac Symptom Protocol

**Clinical Indicators:**
- Chest pain or chest tightness
- Palpitations or irregular heartbeat
- Shortness of breath associated with chest discomfort
- Radiating pain to arm, jaw, or back

**Recommended Appointment Type:** in_person`,
        metadata: {fileName: "cardiology-protocol.md"}
    },
    {
        content: string `## Neurology

**Protocol Name:** Neurological Deficit Protocol

**Clinical Indicators:**
- Sudden numbness or weakness, especially on one side of the body
- Confusion or difficulty speaking
- Severe headache with no known cause
- Seizures or loss of consciousness

**Recommended Appointment Type:** in_person`,
        metadata: {fileName: "neurology-protocol.md"}
    },
    {
        content: string `## Pulmonology

**Protocol Name:** Respiratory Distress Protocol

**Clinical Indicators:**
- Difficulty breathing or shortness of breath
- Persistent cough lasting more than two weeks
- Wheezing
- Chest tightness related to breathing

**Recommended Appointment Type:** in_person`,
        metadata: {fileName: "pulmonology-protocol.md"}
    },
    {
        content: string `## Pediatrics

**Protocol Name:** Pediatric Fever and Illness Protocol

**Clinical Indicators:**
- Fever in infants and children
- Ear pain or irritability in young children
- Rash accompanied by fever
- Reduced feeding or activity in infants

**Recommended Appointment Type:** in_person`,
        metadata: {fileName: "pediatrics-protocol.md"}
    },
    {
        content: string `## Orthopedics

**Protocol Name:** Musculoskeletal Injury Protocol

**Clinical Indicators:**
- Joint pain or swelling
- Suspected fracture or sprain
- Back pain persisting beyond a few days
- Limited range of motion following an injury

**Recommended Appointment Type:** in_person`,
        metadata: {fileName: "orthopedics-protocol.md"}
    },
    {
        content: string `## Gastroenterology

**Protocol Name:** Digestive Symptom Protocol

**Clinical Indicators:**
- Persistent abdominal pain
- Nausea or vomiting lasting more than a day
- Diarrhea or constipation lasting more than a week
- Blood in stool

**Recommended Appointment Type:** teleconsult`,
        metadata: {fileName: "gastroenterology-protocol.md"}
    },
    {
        content: string `## Dermatology

**Protocol Name:** Skin Condition Protocol

**Clinical Indicators:**
- New or changing skin rash
- Persistent itching
- Suspicious moles or skin lesions
- Mild allergic skin reactions

**Recommended Appointment Type:** teleconsult`,
        metadata: {fileName: "dermatology-protocol.md"}
    },
    {
        content: string `## General Practice

**Protocol Name:** General Wellness and Minor Illness Protocol

**Clinical Indicators:**
- Mild cold or flu-like symptoms
- Routine health concerns
- Fatigue without other severe symptoms
- Symptoms that do not clearly match a specialty department

**Recommended Appointment Type:** teleconsult`,
        metadata: {fileName: "general-practice-protocol.md"}
    }
];
