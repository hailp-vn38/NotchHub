#include <stdint.h>

typedef struct OpusBridgeEncoder OpusBridgeEncoder;
typedef struct OpusBridgeDecoder OpusBridgeDecoder;

OpusBridgeEncoder *opus_bridge_encoder_create(void);
void opus_bridge_encoder_destroy(OpusBridgeEncoder *encoder);
int opus_bridge_encode(OpusBridgeEncoder *encoder, const int16_t *pcm, int frame_size, unsigned char *packet, int capacity);
OpusBridgeDecoder *opus_bridge_decoder_create(int sample_rate, int channels);
void opus_bridge_decoder_destroy(OpusBridgeDecoder *decoder);
int opus_bridge_decode(OpusBridgeDecoder *decoder, const unsigned char *packet, int packet_length, int16_t *pcm, int frame_size);
