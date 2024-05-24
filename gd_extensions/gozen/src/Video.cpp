#include "Video.hpp"

void Video::open_video(String a_text)
{
    UtilityFunctions::printerr(a_text);

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
    const AVCodec *av_codec = avcodec_find_decoder(av_stream_video->codecpar->codec_id);
    if (!av_codec)
    {
        UtilityFunctions::printerr("Codec not found video");
        close_video();
        return;
    }

    av_codec_ctx_video = avcodec_alloc_context3(av_codec);
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

    if (avcodec_open2(av_codec_ctx_video, av_codec, NULL) < 0)
    {
        UtilityFunctions::printerr("Error opening codec video");
        close_video();
        return;
    }

    // Audio
    const AVCodec *av_codec = avcodec_find_decoder(av_stream_audio->codecpar->codec_id);
    if (!av_codec)
    {
        UtilityFunctions::printerr("Codec not found audio");
        close_video();
        return;
    }

    av_codec_ctx_audio = avcodec_alloc_context3(av_codec);
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

    if (avcodec_open2(av_codec_ctx_audio, av_codec, NULL) < 0)
    {
        UtilityFunctions::printerr("Error opening codec audio");
        close_video();
        return;
    }

    UtilityFunctions::print("Video opened");
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
}