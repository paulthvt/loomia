import 'dart:convert';
import 'dart:typed_data';

/// A 64×64 PNG for previews and tests: a stand-in, never a real face, never
/// the network.
final Uint8List previewPhoto = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAxUlEQVR42u3YAQ1CMQxF0WcO'
  'NVhCAFZwggww8Mf4LfS1uckE3JNs2To9H/fWSwAAAAAAAAAAAAAAzAXcrpd+gHf00XIHLNJ/'
  'xND/63MNKqlPNKiqPssAIFCfYgAAoBgQrI8b2EIAAHATTwC0f41OmAcmTGQTZuIhvxJ8bAEA'
  '0PMQd73IGr9GU+bJIEPl6UGGfOrPGeSTfo4hw/qvDPKs3zfItn7TIOf6HcN0QHn9R4P869eG'
  'uQCr+oUBgCfAsP7IAABAEPACti2IkjtmSh4AAAAASUVORK5CYII=',
);
