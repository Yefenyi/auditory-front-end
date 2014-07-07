classdef ratemapProc < Processor
    
    properties
        wname       % Window shape descriptor (see window.m)
        wSizeSec    % Window duration in seconds
        hSizeSec    % Step size between windows in seconds
        scaling     % Flag specifying 'magnitude' or 'power'
        decaySec    % Integration time constant (seconds)
    end
    
    properties (GetAccess = private)
        wSize       % Window duration in samples
        hSize       % Step size between windows in samples
        win         % Window vector
        buffer      % Buffered input signals
        rmFilters   % Leaky integrator filters
    end
        
    
    methods
        function pObj = ratemapProc(fs,p,scaling)
            %ratemapProc    Constructs a ratemap processor
            %
            %USAGE
            %  pObj = ratemapProc(fs)
            %  pObj = ratemapProc(fs,p)
            %
            %INPUT PARAMETERS
            %   fs : Sampling frequency (Hz)
            %    p : Structure of non-default parameters
            %
            %OUTPUT PARAMETERS
            % pObj : Processor object
            
            
            if nargin>0 % Safeguard for Matlab empty calls
                
            % Checking input parameters
            if nargin<2||isempty(p)
                p = getDefaultParameters(fs,'processing');
            end
            if nargin == 3 && ~isempty(scaling)
                p.rm_scaling = scaling;
            end
            if isempty(fs)
                error('Sampling frequency needs to be provided')
            end
            
            % Populating properties
            pObj.wname = p.rm_wname;
            pObj.wSizeSec = p.rm_wSizeSec;
            pObj.wSize = 2*round(pObj.wSizeSec*fs/2);
            pObj.hSizeSec = p.rm_hSizeSec;
            pObj.hSize = round(pObj.hSizeSec*fs);
            pObj.win = window(pObj.wname,pObj.wSize);
            pObj.scaling = p.rm_scaling;
            pObj.decaySec = p.rm_decaySec;
                
            % N.B: the filters are instantiated at a later stage, as this
            % requires knowledge of the number of channels
            pObj.rmFilters = [];
                
            pObj.Type = 'Ratemap extractor';
            pObj.FsHzIn = fs;
            pObj.FsHzOut = 1/(pObj.hSizeSec);
            
            % Initialize buffer
            pObj.buffer = [];
                
            end
            
            
        end
        
        function out = processChunk(pObj,in)
            %processChunk       Apply the processor to a new chunk of input
            %                   signal
            %
            %USAGE
            %   out = pObj.processChunk(in)
            %
            %INPUT ARGUMENT
            %    in : New chunk of input data
            %
            %OUTPUT ARGUMENT
            %   out : Corresponding output
            %
            %NOTE: This method does not control dimensionality of the
            %provided input. If called outside of a manager instance,
            %validity of the input is the responsibility of the user!
            
            % Number of channels in input
            nChannels = size(in,2);
            
            % Check if filters are instantiated
            if isempty(pObj.rmFilters)
                pObj.rmFilters = pObj.populateFilters(nChannels,pObj.FsHzIn);
            elseif size(pObj.rmFilters,2)~=nChannels
                % Then something went wrong, re-instantiate filters
                warning('There was a change in number of channels for the ratemap extractor. Resetting filters states...')
                pObj.rmFilters = pObj.populateFilters(nChannels,pObj.FsHzIn);
            end
            
            % Filter input
            for ii = 1:nChannels
                in(:,ii)=pObj.rmFilters(ii).filter(in(:,ii));
            end
            
            
            % Append filtered input to the buffer
            if ~isempty(pObj.buffer)
                in = [pObj.buffer;in];
            end

            
            [nSamples,nChannels] = size(in);
            
            % How many frames are in the buffered input?
            nFrames = max(floor((nSamples-(pObj.wSize-pObj.hSize))/pObj.hSize),1);
            
            % Pre-allocate output
            out = zeros(nFrames,nChannels);
            
            % Loop on the time frame
            for ii = 1:nFrames
                % Get start and end indexes for the current frame
                n_start = (ii-1)*pObj.hSize+1;
                n_end = (ii-1)*pObj.hSize+pObj.wSize;
                
                % Loop on the channel
                for jj = 1:nChannels
                    
                    switch pObj.scaling
                        case 'magnitude'
                            % Averaged magnitude in the windowed frame 
                            out(ii,jj) = mean(pObj.win.*in(n_start:n_end,jj));
                        case 'power'
                            % Averaged energy in the windowed frame for left 
                            out(ii,jj) = mean(power(pObj.win.*in(n_start:n_end,jj),2));
                        otherwise
                            error('Incorrect scaling method for ratemap')
                    end
                end
                
                
            end
            
            % Update the buffer: the input that was not extracted as a
            % frame should be stored
            pObj.buffer = in(nFrames*pObj.hSize+1:end,:);
            
            
        end
            
        function reset(pObj)
            %reset     Resets the internal states of the ratemap extractor
            %
            %USAGE
            %      pObj.reset
            %
            %INPUT ARGUMENTS
            %  pObj : Ratemap processor instance
            
            % Reset the leaky integrators
            if ~isempty(pObj.rmFilters)
                for ii = 1:size(pObj.rmFilters)
                    pObj.rmFilters(ii).reset;
                end
            end
            
            % Empty the buffer
            pObj.buffer = [];
            
        end
        
        function hp = hasParameters(pObj,p)
            %hasParameters  This method compares the parameters of the
            %               processor with the parameters given as input
            %
            %USAGE
            %    hp = pObj.hasParameters(p)
            %
            %INPUT ARGUMENTS
            %  pObj : Processor instance
            %     p : Structure containing parameters to test
            
            
            
            p_list_proc = {'wname','wSizeSec','hSizeSec','scaling','decaySec'};
            p_list_par = {'rm_wname','rm_wSizeSec','rm_hSizeSec','rm_scaling','rm_decaySec'};
            
            % Initialization of a parameters difference vector
            delta = zeros(size(p_list_proc,2),1);
            
            % Loop on the list of parameters
            for ii = 1:size(p_list_proc,2)
                try
                    if ischar(pObj.(p_list_proc{ii}))
                        delta(ii) = ~strcmp(pObj.(p_list_proc{ii}),p.(p_list_par{ii}));
                    else
                        delta(ii) = abs(pObj.(p_list_proc{ii}) - p.(p_list_par{ii}));
                    end
                    
                catch err
                    % Warning: something is missing
                    warning('Parameter %s is missing in input p.',p_list_par{ii})
                    delta(ii) = 1;
                end
            end
            
            % Check if delta is a vector of zeros
            if max(delta)>0
                hp = false;
            else
                hp = true;
            end
         end 
        
    end
    
    methods (Access = private)
        function obj = populateFilters(pObj,nChannels,fs)
            % This function creates an array of filter objects. It returns
            % the array instead of directly setting up the property in pObj
            % as a workaround to a presumable bug
            
            % Preallocate memory
            obj(1,nChannels) = leakyIntegratorFilter(fs,pObj.decaySec);
            
            % Instantiate one filter per channel
            for ii = 1:nChannels-1
                obj(1,ii) = leakyIntegratorFilter(fs,pObj.decaySec);
            end
            
        end
    end
    
end