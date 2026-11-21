// shotglass-kit/sound: note.glsl
//
// Pitch: MIDI note numbers, scales and chords. Notes are integers in MIDI numbering
// (60 = middle C, 69 = A 440 Hz, one step per semitone), so melodies are plain
// integer arithmetic and only become hertz at the end, with kit_note_hz.
//
// A scale or chord is a 12-bit mask of the semitones above its root that it uses
// (bit 0 = the root, bit 7 = the fifth): 0xAB5 is major (0 2 4 5 7 9 11), 0x91 a
// major triad (0 4 7). Degrees past the last note carry on into the next octave, and
// negative degrees go below the root, so a degree is all a melody needs.
// sound: yes

// kit_note_hz(note): frequency of a MIDI note, equal temperament, A4 = 440 Hz.
//   note  MIDI note number (60 = middle C); a float allows detuning (60.1 = 10 cents sharp)
//   ->  hertz
//   e.g. float hz = kit_note_hz(57);   // 220.0 (A3)
float kit_note_hz(float note) { return 440.0 * exp2((note - 69.0) / 12.0); }
float kit_note_hz(int note) { return kit_note_hz(float(note)); }

// kit_hz_note(hz): the MIDI note of a frequency, the inverse of kit_note_hz.
//   hz  hertz, > 0
//   ->  MIDI note number, fractional between semitones (440.0 -> 69.0)
//   e.g. int nearest = int(floor(kit_hz_note(hz) + 0.5));
float kit_hz_note(float hz) { return 69.0 + 12.0 * log2(max(hz, 1e-6) / 440.0); }

// kit_scale_note(degree, root, mask): the note at a degree of any scale or chord.
//   degree  0 = root, 1 = the next note up, ...; any int (past the end: next octave up,
//           negative: below the root)
//   root    MIDI note of degree 0
//   mask    the scale's semitones, bit i = i semitones above the root; bit 0 must be set
//           (a mask without it is treated as if it were). Bits above 11 are ignored.
//   ->  MIDI note number
//   cost: a loop over 12 bits
//   e.g. int n = kit_scale_note(step, 62, 0x6AD);   // D dorian: 0 2 3 5 7 9 10
int kit_scale_note(int degree, int root, int mask) {
    mask = (mask & 0xFFF) | 1;
    int n = 0;
    for (int i = 0; i < 12; i++) n += (mask >> i) & 1;
    int octave = degree >= 0 ? degree / n : -((n - 1 - degree) / n);
    int r = degree - octave * n;   // 0..n-1
    int semi = 0;
    for (int i = 0; i < 12; i++) {
        if (((mask >> i) & 1) != 0) {
            if (r == 0) { semi = i; break; }
            r--;
        }
    }
    return root + 12 * octave + semi;
}

// Scales: kit_scale_<name>(degree, root) is kit_scale_note with that scale's mask.
//   degree  0 = root; past the end goes up an octave, negative goes below the root
//   root    MIDI note of degree 0 (the key)
//   ->  MIDI note number
//   e.g. int n = kit_scale_major(2, 60);         // 64, E: the third of C major
//        int n = kit_scale_minor_pentatonic(5, 57);   // 69, A an octave up
int kit_scale_major(int degree, int root)            { return kit_scale_note(degree, root, 0xAB5); } // 0 2 4 5 7 9 11
int kit_scale_minor(int degree, int root)            { return kit_scale_note(degree, root, 0x5AD); } // 0 2 3 5 7 8 10 (natural)
int kit_scale_harmonic_minor(int degree, int root)   { return kit_scale_note(degree, root, 0x9AD); } // 0 2 3 5 7 8 11
int kit_scale_dorian(int degree, int root)           { return kit_scale_note(degree, root, 0x6AD); } // 0 2 3 5 7 9 10
int kit_scale_pentatonic(int degree, int root)       { return kit_scale_note(degree, root, 0x295); } // 0 2 4 7 9
int kit_scale_minor_pentatonic(int degree, int root) { return kit_scale_note(degree, root, 0x4A9); } // 0 3 5 7 10
int kit_scale_blues(int degree, int root)            { return kit_scale_note(degree, root, 0x4E9); } // 0 3 5 6 7 10

// Chords: kit_chord_<name>(i, root) is the i-th note of the chord, counting up from
// the root; i past the last note carries on into the next octave (an arpeggio that
// keeps climbing), negative i goes below. Same as kit_scale_note with the chord's mask.
//   i     0 = root, 1 = third (or second/fourth for sus), 2 = fifth, 3 = seventh, ...
//   root  MIDI note of the chord's root
//   ->  MIDI note number
//   e.g. int n = kit_chord_minor(i % 3, 57);   // A minor: 57 60 64
//        int n = kit_chord_dom7(step, 55);     // G7 arpeggio, climbing: 55 59 62 65 67 ...
int kit_chord_major(int i, int root) { return kit_scale_note(i, root, 0x091); } // 0 4 7
int kit_chord_minor(int i, int root) { return kit_scale_note(i, root, 0x089); } // 0 3 7
int kit_chord_dim(int i, int root)   { return kit_scale_note(i, root, 0x049); } // 0 3 6
int kit_chord_aug(int i, int root)   { return kit_scale_note(i, root, 0x111); } // 0 4 8
int kit_chord_sus2(int i, int root)  { return kit_scale_note(i, root, 0x085); } // 0 2 7
int kit_chord_sus4(int i, int root)  { return kit_scale_note(i, root, 0x0A1); } // 0 5 7
int kit_chord_maj7(int i, int root)  { return kit_scale_note(i, root, 0x891); } // 0 4 7 11
int kit_chord_min7(int i, int root)  { return kit_scale_note(i, root, 0x489); } // 0 3 7 10
int kit_chord_dom7(int i, int root)  { return kit_scale_note(i, root, 0x491); } // 0 4 7 10

// kit_scale_chord(degree, i, root, mask): the i-th note of the chord built on a degree
// of a scale, by stacking thirds within the scale (degree, degree + 2, degree + 4, ...).
// In a major scale, degrees 0 3 4 5 give the I IV V vi chords, with the right major
// and minor qualities for free.
//   degree  the chord's root as a scale degree (0 = the key's root)
//   i       0 = root, 1 = third, 2 = fifth, 3 = seventh; any int, as for kit_scale_note
//   root    MIDI note of the key
//   mask    the scale's semitones, as for kit_scale_note
//   ->  MIDI note number
//   cost: one kit_scale_note
//   e.g. int n = kit_scale_chord(4, i, 60, 0xAB5);   // the V chord of C major: G B D
int kit_scale_chord(int degree, int i, int root, int mask) {
    return kit_scale_note(degree + 2 * i, root, mask);
}
