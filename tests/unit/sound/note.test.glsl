// sound/note.glsl: MIDI pitch, scales and chords.
#include <sound/note.glsl>

void test_note_hz() {
    expect_eq(kit_note_hz(69), 440.0);
    expect_near(kit_note_hz(57), 220.0, 1e-4);
    expect_near(kit_note_hz(81), 880.0, 1e-3);
    expect_near(kit_note_hz(60), 261.6255653, 1e-3);          // middle C
    expect_near(kit_note_hz(69.1), 440.0 * exp2(0.1 / 12.0), 1e-3);   // detuned
}

void test_hz_note_inverts_note_hz(float x) {
    float n = mix(10.0, 120.0, x);
    expect_near(kit_hz_note(kit_note_hz(n)), n, 1e-4);
    expect_near(kit_note_hz(n + 12.0) / kit_note_hz(n), 2.0, 1e-5);   // an octave doubles
}

void test_hz_note_guards_zero() {
    expect_finite(kit_hz_note(0.0));
    expect_finite(kit_hz_note(-5.0));
}

void test_scales() {
    // C major from middle C: 60 62 64 65 67 69 71, then 72
    int c_major[8] = int[8](60, 62, 64, 65, 67, 69, 71, 72);
    for (int i = 0; i < 8; i++) expect_eq(kit_scale_major(i, 60), c_major[i]);
    expect_eq(kit_scale_major(-1, 60), 59);                   // below the root
    expect_eq(kit_scale_major(-7, 60), 48);
    expect_eq(kit_scale_major(14, 60), 84);                   // two octaves up
    expect_eq(kit_scale_minor(2, 57), 60);                    // A minor: A B C
    expect_eq(kit_scale_harmonic_minor(6, 57), 68);           // the raised 7th
    expect_eq(kit_scale_dorian(5, 62), 71);                   // D dorian: B natural
    expect_eq(kit_scale_pentatonic(3, 60), 67);
    expect_eq(kit_scale_minor_pentatonic(5, 57), 69);         // the header's example
    expect_eq(kit_scale_blues(3, 60), 66);                    // the blue note
}

void test_chords() {
    expect_eq(ivec3(kit_chord_major(0, 60), kit_chord_major(1, 60), kit_chord_major(2, 60)), ivec3(60, 64, 67));
    expect_eq(ivec3(kit_chord_minor(0, 57), kit_chord_minor(1, 57), kit_chord_minor(2, 57)), ivec3(57, 60, 64));
    expect_eq(ivec3(kit_chord_dim(0, 60), kit_chord_dim(1, 60), kit_chord_dim(2, 60)), ivec3(60, 63, 66));
    expect_eq(ivec3(kit_chord_aug(0, 60), kit_chord_aug(1, 60), kit_chord_aug(2, 60)), ivec3(60, 64, 68));
    expect_eq(ivec3(kit_chord_sus2(0, 60), kit_chord_sus2(1, 60), kit_chord_sus2(2, 60)), ivec3(60, 62, 67));
    expect_eq(ivec3(kit_chord_sus4(0, 60), kit_chord_sus4(1, 60), kit_chord_sus4(2, 60)), ivec3(60, 65, 67));
    expect_eq(ivec4(kit_chord_maj7(0, 60), kit_chord_maj7(1, 60), kit_chord_maj7(2, 60), kit_chord_maj7(3, 60)), ivec4(60, 64, 67, 71));
    expect_eq(ivec4(kit_chord_min7(0, 60), kit_chord_min7(1, 60), kit_chord_min7(2, 60), kit_chord_min7(3, 60)), ivec4(60, 63, 67, 70));
    // G7 climbing: 55 59 62 65 67 (the header's example)
    expect_eq(ivec4(kit_chord_dom7(0, 55), kit_chord_dom7(1, 55), kit_chord_dom7(2, 55), kit_chord_dom7(3, 55)), ivec4(55, 59, 62, 65));
    expect_eq(kit_chord_dom7(4, 55), 67);
    expect_eq(kit_chord_major(-1, 60), 55);                   // below the root
}

void test_scale_chord() {
    // In C major, degrees 0 3 4 5 give C F G Am
    expect_eq(ivec3(kit_scale_chord(0, 0, 60, 0xAB5), kit_scale_chord(0, 1, 60, 0xAB5), kit_scale_chord(0, 2, 60, 0xAB5)), ivec3(60, 64, 67));
    expect_eq(ivec3(kit_scale_chord(4, 0, 60, 0xAB5), kit_scale_chord(4, 1, 60, 0xAB5), kit_scale_chord(4, 2, 60, 0xAB5)), ivec3(67, 71, 74));
    expect_eq(ivec3(kit_scale_chord(5, 0, 60, 0xAB5), kit_scale_chord(5, 1, 60, 0xAB5), kit_scale_chord(5, 2, 60, 0xAB5)), ivec3(69, 72, 76));
}

// Any degree: moving one degree up never goes down, and n degrees up is an octave.
void test_scale_note_degrees(float x) {
    int d = int(floor(mix(-40.0, 40.0, x)));
    int masks[4] = int[4](0xAB5, 0x295, 0x091, 0x4E9);
    int sizes[4] = int[4](7, 5, 3, 6);
    for (int k = 0; k < 4; k++) {
        int a = kit_scale_note(d, 60, masks[k]);
        expect(kit_scale_note(d + 1, 60, masks[k]) > a, float(a));
        expect_eq(kit_scale_note(d + sizes[k], 60, masks[k]), a + 12);
    }
}

void test_scale_note_masks() {
    expect_eq(kit_scale_note(1, 60, 0x090), 64);       // bit 0 is set for you: 0 4 7
    expect_eq(kit_scale_note(3, 60, 0xF091), 72);      // bits above 11 are ignored
    expect_eq(kit_scale_note(5, 60, 0), 120);          // root only: every degree an octave
}
