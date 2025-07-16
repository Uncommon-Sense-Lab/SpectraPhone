function [v, labels] = ExtractVideo(filename)
% Read the video
    x = VideoReader(filename);
    % Initialize output
    nFrames = floor(x.Duration*x.FrameRate);
%     v=zeros(x.Height, x.Width, nFrames);
    labels = zeros(1, nFrames);

    h = x.Height;
    w = x.Width;

    for i = 1:nFrames
        xv = readFrame(x);
    %     max(max(xv))
        for j = 1:h
            for k = 1:w
                v(j, k, i) = (xv(j, k,  1) + xv(j, k,  2) + xv(j, k,  3)) / 3.0;
            end
        end
        filename(find(filename == '.',1,'last'):end) = []; %remove extensio
        C = regexp(filename, '_', 'split');
        l = string(C(1));
        pat = digitsPattern;
        p = extract(l,pat);
        labels(i) =  str2num(p(end));

    end

end
