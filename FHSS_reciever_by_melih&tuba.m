function FHSS_reciever()
    % Create GUI
    fig = uifigure('Name', 'FHSS Receiver', 'Position', [100, 100, 500, 500]);

    % Input fields
    uilabel(fig, 'Position', [20, 450, 120, 22], 'Text', 'Sampling Rate (Hz):');
    samplingRateField = uieditfield(fig, 'numeric', 'Position', [150, 450, 300, 22]);

    uilabel(fig, 'Position', [20, 410, 120, 22], 'Text', 'Recording Duration (s):');
    durationField = uieditfield(fig, 'numeric', 'Position', [150, 410, 300, 22]);

    % Buttons
    uibutton(fig, 'Position', [150, 350, 200, 30], 'Text', 'Record and Decode', ...
        'ButtonPushedFcn', @(btn, event) recordAndDecode());

    function recordAndDecode()
        % Get sampling rate and duration
        samplingRate = samplingRateField.Value;
        duration = durationField.Value;

        % Record audio
        recorder = audiorecorder(samplingRate, 16, 1);
        disp('Recording...');
        recordblocking(recorder, duration);
        receivedSignal = getaudiodata(recorder);
        disp('Recording completed.');

        % Plot spectrogram before filtering
        subplot(3, 1, 1);
        spectrogram(receivedSignal, 256, 200, 256, samplingRate, 'yaxis');
        title('Spectrogram Before Filtering');

        % Apply bandpass filter and get the filtered signal
        filteredSignal = applyBandpassFilter(receivedSignal, samplingRate);

        % Plot spectrogram after filtering
        subplot(3, 1, 2);
        spectrogram(filteredSignal, 256, 200, 256, samplingRate, 'yaxis');
        title('Spectrogram After Filtering');

        % Decode the signal to binary data
        binaryDatas = decodeFHSS(filteredSignal, samplingRate);
        disp('Binary Data:');
        disp(binaryDatas);

        decodedText = binarytoText(binaryDatas);
        disp('Decoded Text Message:');
        disp(decodedText);

            
    end

    function filteredSignal = applyBandpassFilter(receivedSignal, samplingRate)
        % Bandpass filter to focus on frequencies between 1000 and 5000 Hz
        lowFreq = 500;  % Lower bound of hop frequencies
        highFreq = 5000; % Upper bound of hop frequencies

        % Normalize frequency range (0 to 1 relative to Nyquist frequency)
        nyquist = samplingRate / 2;
        [b, a] = butter(4, [lowFreq, highFreq] / nyquist, 'bandpass');

        % Apply filter
        filteredSignal = filter(b, a, receivedSignal);
    end

    function binaryDatas = decodeFHSS(filteredSignal, samplingRate)
        % Parameters for decoding
        hopPeriod = 1.0; % Hop period in seconds
        deltaF = 100; % Frequency deviation for 2-FSK
        studentNumber = 2516581; % Student number for frequency table
        freqTable = generateFreqTable(studentNumber);
        pilotFrequency = 600; % Predetermined pilot frequency
        tolerance = 10; % Tolerance for detecting pilot signal (in Hz)

        % Divide signal into hop periods
        hopSamples = round(hopPeriod * samplingRate);
        numHops = floor(length(filteredSignal) / hopSamples);
        
        % Synchronize and decode each hop
        rng(1); % Same random seed as in the transmitter
        hopOrder = randi(length(freqTable), 1, numHops); % Same hopping sequence as in transmitter
        display(hopOrder);

        % Define pilot signal parameters
pilotFrequency = 600; % Frequency of the pilot signal
tolerance = 100; % Frequency tolerance for pilot detection (Hz)

% Initialize variables
startIdx = []; % Start index after detecting the first pilot
endIdx = []; % End index after detecting the second pilot
detectedFrequencies = []; % Empty matrix to store detected frequencies

% Loop through hops
for i = 1:numHops
    % Extract segment for current hop
    startSampleIdx = (i-1) * hopSamples + 1;
    endSampleIdx = min(startSampleIdx + hopSamples - 1, length(filteredSignal));
    hopSegment = filteredSignal(startSampleIdx:endSampleIdx);

    % Perform time-frequency analysis for frequency detection
    [S, F, T] = spectrogram(hopSegment, 256, 200, 256, samplingRate);
    [~, maxIdx] = max(abs(S), [], 1); % Find the frequency index with max magnitude
    detectedFreq = F(maxIdx(1)); % Extract the corresponding frequency
    display(['Detected Frequency: ', num2str(detectedFreq)]);

    % Check if the frequency matches the pilot signal
    if abs(detectedFreq - pilotFrequency) < tolerance
        % If the first pilot signal is not yet detected, set startIdx
        if isempty(startIdx)
            startIdx = startSampleIdx;
            disp('First pilot signal detected. Start processing.');
        % If the first pilot is already detected and another pilot is found, set endIdx
        elseif isempty(endIdx)
            endIdx = startSampleIdx;
            disp('Second pilot signal detected. Stop processing.');
            break; % Exit the loop once the second pilot is detected
        end
        continue; % Skip further processing for this hop (pilot signals are not data)
    end

    % Store detected frequency only if between pilot signals
    if ~isempty(startIdx) && isempty(endIdx)
        detectedFrequencies = [detectedFrequencies, detectedFreq];
    end


% Display the stored detected frequencies
disp('Detected Frequencies (between pilots):');
disp(detectedFrequencies);

    % Ensure the sizes of detectedFrequencies and hopOrder match
numDetected = length(detectedFrequencies);
numHopFreqs = length(hopOrder);

% Initialize binaryData
binaryDatas = [];

% Loop through each detected frequency
for j = 1:min(numDetected, numHopFreqs)
    % Get the corresponding hop frequency from freqTable
    hopFreq = freqTable(hopOrder(j));
    detectedFreqs = detectedFrequencies(j);
    
    % Display the values for debugging
    disp(['Detected Frequency: ', num2str(detectedFreqs), ', Hop Frequency: ', num2str(hopFreq)]);
    
    % Calculate the frequency difference
    frequencyDifference = detectedFreqs - hopFreq;

    % Demodulate signal
    if abs(frequencyDifference - (-deltaF)) < abs(frequencyDifference - (+deltaF))
        binaryDatas = [binaryDatas, 0]; % Closest to f_h - deltaF
    else
        binaryDatas = [binaryDatas, 1]; % Closest to f_h + deltaF
    end
end

% Display the decoded binary data
disp('Decoded Binary Data:');
disp(binaryDatas);
binaryDatas = binaryDatas(:).'; % Convert to row vector
disp(length(binaryDatas))

end

    function freqTable = generateFreqTable(studentNumber)
        % Generate frequency table for Category 1 based on student number
        digits = num2str(studentNumber) - '0';
        N6 = digits(6);
        N7 = digits(7);

        % Calculate b and S
        b = 1; % b = 1 if N6 is even; otherwise b = -1
        if mod(N6, 2) ~= 0
            b = -1;
        end

        S = 100 * mod(N7, 5); % S = 100 × (N7 % 5)

        % Generate frequency table for Category 1
        baseFreqs = [1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000];
        freqTable = baseFreqs + b * S;
    end
end

function text = binarytoText(binaryDatas)
        

      
        % Convert binary vector to text
        binaryMatrix = reshape(binaryDatas, 8, []).'; % Reshape to 8-bit chunks
        text = char(bin2dec(num2str(binaryMatrix))); % Convert to characters
        disp('obtained text:');
        disp(text);
    end
end