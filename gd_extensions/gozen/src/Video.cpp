#include "Video.hpp"

void Video::open_video(String a_text)
{
    UtilityFunctions::print(a_text);

    av_format_ctx = avformat_alloc_context();
    if (!av_format_ctx)
    {
        UtilityFunctions::printerr("Error allocating format context");
        return;
    }

    if (avformat_open_input(&av_format_ctx, a_text.utf8().get_data(), NULL, NULL) != 0)
    {
        UtilityFunctions::printerr("Error opening video file!");
        close_video();
        return;
    }

    if (avformat_find_stream_info(av_format_ctx, NULL) < 0)
    {
        UtilityFunctions::printerr("Couldn't find stream information");
        close_video();
        return;
    }

    for (int i = 0; i < av_format_ctx->nb_streams; i++)
    {
        AVCodecParameters *av_codec_params = av_format_ctx->streams[i]->codecpar;

        if (avcodec_find_decoder(av_codec_params->codec_id) == NULL)
        {
            continue;
        }
        else if (av_codec_params->codec_type == AVMEDIA_TYPE_VIDEO)
        {
            av_stream_video = av_format_ctx->streams[i];
        }
        else if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO)
        {
            av_stream_audio = av_format_ctx->streams[i];
        }       
    }

    // Video
    const AVCodec *av_codec_video = avcodec_find_decoder(av_stream_video->codecpar->codec_id);
    if (!av_codec_video)
    {
        UtilityFunctions::printerr("Codec not found video");
        close_video();
        return;
    }

    av_codec_ctx_video = avcodec_alloc_context3(av_codec_video);
    if (!av_codec_ctx_video)
    {
        UtilityFunctions::printerr("Error allocating codec context video");
        close_video();
        return;
    }

    if (avcodec_parameters_to_context(av_codec_ctx_video, av_stream_video->codecpar) < 0)
    {
        UtilityFunctions::printerr("Error attaching codec parameters to codec context video");
        close_video();
        return;
    }

    if (avcodec_open2(av_codec_ctx_video, av_codec_video, NULL) < 0)
    {
        UtilityFunctions::printerr("Error opening codec video");
        close_video();
        return;
    }

    // Audio
    const AVCodec *av_codec_audio = avcodec_find_decoder(av_stream_audio->codecpar->codec_id);
    if (!av_codec_audio)
    {
        UtilityFunctions::printerr("Codec not found audio");
        close_video();
        return;
    }

    av_codec_ctx_audio = avcodec_alloc_context3(av_codec_audio);
    if (!av_codec_ctx_audio)
    {
        UtilityFunctions::printerr("Error allocating codec context audio");
        close_video();
        return;
    }

    if (avcodec_parameters_to_context(av_codec_ctx_audio, av_stream_audio->codecpar) < 0)
    {
        UtilityFunctions::printerr("Error attaching codec parameters to codec context audio");
        close_video();
        return;
    }

    if (avcodec_open2(av_codec_ctx_audio, av_codec_audio, NULL) < 0)
    {
        UtilityFunctions::printerr("Error opening codec audio");
        close_video();
        return;
    }

    av_codec_ctx_audio->request_sample_fmt = AV_SAMPLE_FMT_S16;

    response = swr_alloc_set_opts2(
        &swr_ctx, 
        &av_codec_ctx_audio->ch_layout, AV_SAMPLE_FMT_S16, av_codec_ctx_audio->sample_rate, 
        &av_codec_ctx_audio->ch_layout, av_codec_ctx_audio->sample_fmt, av_codec_ctx_audio->sample_rate,
        0, nullptr
    );
    if (response < 0)
    {
        print_av_error("Fail to obtain swr context");
        close_video();
        return;
    } else if (!swr_ctx)
    {
        UtilityFunctions::printerr("Could not allocate re-sampler context");
        close_video();
        return;
    }
    
    response = swr_init(swr_ctx);
    if (response < 0)
    {
        print_av_error("Fail to initialize swr context");
        close_video();
        return;
    }

    UtilityFunctions::print("Video opened");
    is_open = true;
}

void Video::close_video()
{
    is_open = false;

    if (av_format_ctx)
        avformat_close_input(&av_format_ctx);
    
    if (av_codec_ctx_video)
        avcodec_free_context(&av_codec_ctx_video);
    
    if (av_codec_ctx_audio)
        avcodec_free_context(&av_codec_ctx_audio);
    
    if (swr_ctx)
        swr_free(&swr_ctx);

    if (av_frame)
        av_frame_free(&av_frame);
    
    if (av_packet)
        av_packet_free(&av_packet);
}

Ref<AudioStreamWAV> Video::get_audio()
{
    Ref<AudioStreamWAV> audio_wav = memnew(AudioStreamWAV);

    if (!is_open)
    {
        UtilityFunctions::printerr("Video not open yet!");
        return audio_wav;
    }

    response = av_seek_frame(av_format_ctx, av_stream_audio->index, 0, AVSEEK_FLAG_FRAME | AVSEEK_FLAG_ANY);
    avcodec_flush_buffers(av_codec_ctx_audio);
    if (response < 0)
    {
        UtilityFunctions::printerr("Error seek to the beginning!");
        return audio_wav;
    }

    av_frame = av_frame_alloc();
    av_packet = av_packet_alloc();
    PackedByteArray audio_data;

    while (av_read_frame(av_format_ctx, av_packet) >= 0)
    {
        if (av_packet->stream_index == av_stream_audio->index)
        {
            response = avcodec_send_packet(av_codec_ctx_audio, av_packet) == 0;
            if (response < 0)
            {
                UtilityFunctions::printerr("Error decoding audio packet");
                av_packet_unref(av_packet);
                break;
            } 
            
            while (response >= 0)
            {
                response =  avcodec_receive_frame(av_codec_ctx_audio, av_frame);
                if (response == AVERROR(EAGAIN) || response == AVERROR_EOF)
                {
                    break;
                }
                else if (response < 0)
                {
                    UtilityFunctions::printerr("Error decoding audio frame");
                    break;
                }

                AVFrame* av_new_frame = av_frame_alloc();
                av_new_frame->format = AV_SAMPLE_FMT_S16;
                av_new_frame->ch_layout = av_frame->ch_layout;
                av_new_frame->sample_rate = av_frame->sample_rate;
                av_new_frame->nb_samples = swr_get_out_samples(swr_ctx, av_frame->nb_samples);

                response = av_frame_get_buffer(av_new_frame, 0);
                if (response < 0)
                {
                    print_av_error("Could not create new frame for swr");
                    av_frame_unref(av_new_frame);
                    av_frame_unref(av_frame);
                    break;
                }

                response = swr_convert_frame(swr_ctx, av_new_frame, av_frame);
                if (response < 0)
                {
                    print_av_error("Could not convert audio frame");
                    av_frame_unref(av_new_frame);
                    av_frame_unref(av_frame);
                    break;
                }

                if (swr_get_out_samples(swr_ctx, av_frame->nb_samples) != av_new_frame->nb_samples)
                    UtilityFunctions::printerr("Number of Samples mismatch");
                
                // av_new_frame? av_frame?
                size_t unpadded_line_size = av_new_frame->nb_samples * av_get_bytes_per_sample(AV_SAMPLE_FMT_S16);
                std::vector<uint16_t> audio_vector(unpadded_line_size);
                memcpy(audio_vector.data(), av_new_frame->extended_data[0], unpadded_line_size);

                byte_array = PackedByteArray();
                byte_array.resize(unpadded_line_size * 2);

                uint16_t byte_offset = 0;
                for (size_t i = 0; i < unpadded_line_size; i++)
                {
                    uint16_t value = ((uint16_t *)av_new_frame->extended_data[0])[i];
                    byte_array.encode_s16(byte_offset, value);
                    byte_offset += sizeof(uint16_t);
                }

                audio_data.append_array(byte_array);
                av_frame_unref(av_frame);
                av_frame_unref(av_new_frame);
            }

        }

        av_packet_unref(av_packet);
    }

    av_frame_free(&av_frame);
    av_packet_free(&av_packet);

    audio_wav->set_format(AudioStreamWAV::FORMAT_16_BITS);
    audio_wav->set_data(audio_data);
    audio_wav->set_mix_rate(av_codec_ctx_audio->sample_rate);
    audio_wav->set_stereo(av_codec_ctx_audio->ch_layout.nb_channels >= 2);

    return audio_wav;
}

void Video::print_av_error(const char *a_message)
{
    char error_message[AV_ERROR_MAX_STRING_SIZE];
    av_strerror(response, error_message, sizeof(error_message));
    UtilityFunctions::printerr((std::string(a_message) + ": " + error_message).c_str());
}