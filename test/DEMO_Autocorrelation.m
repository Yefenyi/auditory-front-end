clear;
close all
clc


% Load a signal
load('TestBinauralCues');

% Take right ear signal
data = earSignals(1:62E3,2); 
% data = earSignals(1:15E3,2);     

% New sampling frequency
fsHzRef = 16E3;

% Resample
data = resample(data,fsHzRef,fsHz);

% Copy fs
fsHz = fsHzRef;

% Request ratemap    
requests = {'autocorrelation'};

ac_wSizeSec  = 0.02;
ac_hSizeSec  = 0.01;
ac_clipAlpha = 0.0;
ac_K         = 2;


% Parameters
par = genParStruct('gt_lowFreqHz',80,'gt_highFreqHz',8000,'gt_nChannels',32,'ihc_method','dau','ac_wSizeSec',ac_wSizeSec,'ac_hSizeSec',ac_hSizeSec,'ac_clipAlpha',ac_clipAlpha,'ac_K',ac_K); 

% Create a data object
dObj = dataObject(data,fsHz);

% Create a manager
mObj = manager(dObj,requests,par);

% Request processing
mObj.processSignal();

ihc = [dObj.innerhaircell{1}.Data(:)];

acf = [dObj.autocorrelation{1}.Data(:)];

% Pause in seconds between two consecutive plots 
pauseSec = 0.0125;



%% Plot the ACF

zoom1 = 3;
zoom2 = 3;
bNorm = true;

frameIdx2Plot = 10;

wSizeSamples = 0.5 * round((ac_wSizeSec * fsHz * 2));
wStepSamples = round((ac_hSizeSec * fsHz));

samplesIdx = (1:wSizeSamples) + ((frameIdx2Plot-1) * wStepSamples);

lagsMS = dObj.autocorrelation{1}.lags*1E3;

figure;
waveplot(ihc(samplesIdx,:),samplesIdx/fsHz,dObj.autocorrelation{1}.cfHz,zoom1,bNorm)
xlabel('Time (s)')
ylabel('Center frequency (Hz)')
title('IHC signal')

figure;
ax(1) = subplot(4,1,[1:3]);
waveplot(permute(acf(frameIdx2Plot,:,:),[3 1 2]),lagsMS,dObj.autocorrelation{1}.cfHz,zoom2,bNorm)
xlabel('')
hy = ylabel('Center frequency (Hz)');
hypos = get(hy,'position');
hypos(1) = -2.15;
set(hy,'position',hypos);
ht = title('ACF');
htpos = get(ht,'position');
htpos(2) = htpos(2) * 0.985;
set(ht,'position',htpos);

ax(2) = subplot(4,1,4);
plot(lagsMS,mean(permute(acf(frameIdx2Plot,:,:),[3 1 2]),3),'k','linewidth',1.25)
grid on
xlim([lagsMS(1) lagsMS(end)])
ylim([0 1])
xlabel('Lag period (ms)')
ylabel('SACF')




%% Show a ACF movie
% 
% y-axis is slightly moving in the movie, might consider fixing it
if 1
    figure;
    
    % Loop over the number of frames
    for ii = 1 : size(acf,1)
        cla;
        waveplot(permute(acf(ii,:,:),[3 1 2]),dObj.autocorrelation{1}.lags,dObj.autocorrelation{1}.cfHz)
        pause(pauseSec);
        title(['Frame number ',num2str(ii)])
    end
end


% %% Plot Gammatone response
% % 
% % 
% % Basilar membrane output
% bm   = [dObj.gammatone{1}.Data(:,:)];
% % Envelope
% env  = [dObj.innerhaircell{1}.Data(:,:)];
% fHz  = dObj.gammatone{1}.cfHz;
% tSec = (1:size(bm,1))/fsHz;
% 
% zoom  = [];
% bNorm = [];
% 
% 
% figure;
% waveplot(bm(1:3:end,:),tSec(1:3:end),fHz,zoom,bNorm);
% 
% figure;
% waveplot(env(1:3:end,:),tSec(1:3:end),fHz,zoom,bNorm);
