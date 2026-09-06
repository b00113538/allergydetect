export interface SymptomOption {
  id: string;
  label: string;
  emergency?: boolean;
}

export const SYMPTOM_OPTIONS: SymptomOption[] = [
  { id: "rash_hives", label: "Rash / Hives" },
  { id: "sneezing", label: "Sneezing" },
  { id: "itchy_eyes", label: "Itchy Eyes" },
  { id: "headache", label: "Headache" },
  { id: "brain_fog", label: "Brain Fog" },
  { id: "bloating", label: "Bloating" },
  { id: "cramping", label: "Cramping" },
  { id: "nausea", label: "Nausea" },
  { id: "fatigue", label: "Fatigue" },
  { id: "palpitations", label: "Palpitations" },
  { id: "swollen_lips", label: "Swollen Lips", emergency: true },
  { id: "difficulty_breathing", label: "Difficulty Breathing", emergency: true },
  { id: "skin_flushing", label: "Skin Flushing" },
  { id: "diarrhoea", label: "Diarrhoea" },
];
