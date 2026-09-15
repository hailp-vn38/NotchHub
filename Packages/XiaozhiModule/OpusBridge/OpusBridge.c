#include "OpusBridge.h"
#include <opus/opus.h>
#include <stdlib.h>

struct OpusBridgeEncoder { OpusEncoder *value; };
struct OpusBridgeDecoder { OpusDecoder *value; };

OpusBridgeEncoder *opus_bridge_encoder_create(void) {
    int error = OPUS_OK;
    OpusEncoder *value = opus_encoder_create(16000, 1, OPUS_APPLICATION_AUDIO, &error);
    if (error != OPUS_OK) return NULL;
    opus_encoder_ctl(value, OPUS_SET_DTX(1));
    opus_encoder_ctl(value, OPUS_SET_INBAND_FEC(0));
    OpusBridgeEncoder *encoder = malloc(sizeof(*encoder));
    if (encoder == NULL) { opus_encoder_destroy(value); return NULL; }
    encoder->value = value;
    return encoder;
}

void opus_bridge_encoder_destroy(OpusBridgeEncoder *encoder) {
    if (encoder != NULL) { opus_encoder_destroy(encoder->value); free(encoder); }
}

int opus_bridge_encode(OpusBridgeEncoder *encoder, const int16_t *pcm, int frame_size, unsigned char *packet, int capacity) {
    return encoder == NULL ? OPUS_BAD_ARG : opus_encode(encoder->value, pcm, frame_size, packet, capacity);
}

OpusBridgeDecoder *opus_bridge_decoder_create(int sample_rate, int channels) {
    int error = OPUS_OK;
    OpusDecoder *value = opus_decoder_create(sample_rate, channels, &error);
    if (error != OPUS_OK) return NULL;
    OpusBridgeDecoder *decoder = malloc(sizeof(*decoder));
    if (decoder == NULL) { opus_decoder_destroy(value); return NULL; }
    decoder->value = value;
    return decoder;
}

void opus_bridge_decoder_destroy(OpusBridgeDecoder *decoder) {
    if (decoder != NULL) { opus_decoder_destroy(decoder->value); free(decoder); }
}

int opus_bridge_decode(OpusBridgeDecoder *decoder, const unsigned char *packet, int packet_length, int16_t *pcm, int frame_size) {
    return decoder == NULL ? OPUS_BAD_ARG : opus_decode(decoder->value, packet, packet_length, pcm, frame_size, 0);
}
