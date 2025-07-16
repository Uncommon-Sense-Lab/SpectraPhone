function [x, y, nFrames] = videoInfo(filename)
    x = VideoReader(filename);
    nFrames = floor(x.Duration*x.FrameRate)
    
    y = x.Height
    x = x.Width

end
