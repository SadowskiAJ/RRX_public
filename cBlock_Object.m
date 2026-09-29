classdef cBlock_Object
    properties
        vdArcLength = zeros(600, 1, 'double') % Vector of arc length values
        vdLPF = zeros(600, 1, 'double') % Vector of load proportionality factors
        vdU = zeros(600, 1, 'double') % Vector of meridional edge displacements
        vdMaxRes = zeros(600, 1, 'double') % Vector of maximum residuals
        vnNeigs = zeros(600, 1, 'int32') % Vector of number of negative eigenvalues
        sFingerprint % unique deterministic 64-char lowercase hex character vector fingerprint
    end

    methods
        function obj = cBlock_Object(fID) % Constructor
            I = 1; % Index for storing data in vectors
            while ~feof(fID)
                pos = ftell(fID); % Get current file position
                line = fgetl(fID); % Read a line of text
                if isequal(line, -1); break; end % End of file check
                line = strtrim(line);
                if isempty(line); continue; end % Ignore blank separators
                % Only a leading # marks a section. Legacy NaNs such as
                % -1.#IND contain # inside a numeric field.
                if startsWith(line, '#'); fseek(fID, pos, 'bof'); break; end

                try
                    obj = obj.parseLine_textscan(line,I);
                catch ME
                    error('Failed to parse line: %s\nError: %s', line, ME.message);
                end

                I = I + 1; % Increment index for next data entry
            end

            if I == 1
                error('cBlock_Object:EmptyBlock', 'Analysis block contains no data rows.');
            end

            % Trim unused preallocated space
            obj.vdArcLength = obj.vdArcLength(1:I-1);
            obj.vdLPF = obj.vdLPF(1:I-1);
            obj.vdU = obj.vdU(1:I-1);
            obj.vdMaxRes = obj.vdMaxRes(1:I-1);
            obj.vnNeigs = obj.vnNeigs(1:I-1);

            % Compute own fingerprint
            obj.sFingerprint = obj.Fingerprint();
        end
        %
        % function out = ArcLengthCheckSum(obj, X)
        %     out = obj.FieldChecksum(X, 'vdArcLength');
        % end
        %
        % function out = LoadProportionalityCheckSum(obj, X)
        %     out = obj.FieldChecksum(X, 'vdLPF');
        % end
        %
        % function out = MeridionalDisplacementCheckSum(obj, X)
        %     out = obj.FieldChecksum(X, 'vdU');
        % end
        %
        % function out = MaxResidualCheckSum(obj, X)
        %     out = obj.FieldChecksum(X, 'vdMaxRes');
        % end
        %
        % function out = NeigsCheckSum(obj)
        %     out = uint64(0);
        %     for I = 1:length(obj.vnNeigs); out = out + obj.vnNeigs(I); end
        % end
        %
        % function out = CheckSum(obj, X)
        %     out = uint64(0);
        %     out = out + obj.ArcLengthCheckSum(X);
        %     out = out + obj.LoadProportionalityCheckSum(X);
        %     out = out + obj.MeridionalDisplacementCheckSum(X);
        %     out = out + obj.MaxResidualCheckSum(X);
        % end

        function out = ArcLengthNthDigit(obj, inc, n)
            if inc > length(obj.vdArcLength); out = nan;
            else; out = obj.nthSignificantDigit(obj.vdArcLength(inc), n);
            end
        end

        function out = LPFNthDigit(obj, inc, n)
            if inc > length(obj.vdLPF); out = nan;
            else; out = obj.nthSignificantDigit(obj.vdLPF(inc), n);
            end
        end
    end

    methods (Access = private)
        function obj = parseLine_textscan(obj, line, I)
            % Robust CSV line parser for 5 columns: 4 doubles then an integer.
            if isstring(line); line = char(line); end

            % Split and trim tokens
            tokens = strtrim(strsplit(line, ',', 'CollapseDelimiters', false));
            if numel(tokens) ~= 5
                error('Expected exactly 5 comma-separated fields; found %d.', numel(tokens));
            end

            % Parse columns 1-3 (arc length, LPF, U) which must be finite
            v = NaN(1,4); nVal = int32(-1);
            for k = 1:3
                v(k) = obj.ParseFiniteNumber(tokens{k}, sprintf('Column %d', k));
            end
            if v(1) < 0 || (I > 1 && v(1) < obj.vdArcLength(I-1))
                error('Arc length must be nonnegative and nondecreasing.');
            end

            % Parse column 4 (max. residual) which may be nan
            if ~obj.bIsMissingToken(tokens{4})
                v(4) = obj.ParseFiniteNumber(tokens{4}, 'Force residual');
            end

            % Parse column 5 (negative eigenvalue count) which may be nan
            if ~obj.bIsMissingToken(tokens{5})       
                nVal = obj.ParseFiniteNumber(tokens{5}, 'Negative-eigenvalue count');
                
                if nVal ~= fix(nVal)
                    error('Negative-eigenvalue count is not an integer: "%s".', tokens{5});
                end
                
                if nVal < 0 || nVal > double(intmax('int32'))
                    error('Negative-eigenvalue count is outside the valid range: "%s".', tokens{5});
                end
                % Convert the parsed numeric scalar, not the character token.
                nVal = int32(nVal);
            end

            % Assign values safely (store NaNs where appropriate)
            obj.vdArcLength(I) = v(1);
            obj.vdLPF(I)       = v(2);
            obj.vdU(I)         = v(3);
            obj.vdMaxRes(I)    = v(4);
            obj.vnNeigs(I)     = nVal; % ensure integer type, -1 is 'nan' sentinel
        end

        function tf = bIsMissingToken(~, token)
            token = lower(strtrim(token));
            % Recognised NaN spellings all map to the same NaN / int32(-1).
            % Empty fields and arbitrary malformed text remain errors.
            tf = ~isempty(regexp(token, ...
                '^[+-]?(?:nan(?:\(ind\))?|1\.#(?:ind|qnan|snan))$', 'once'));
        end

        function value = ParseFiniteNumber(~, token, fieldName)
            % Real decimal/scientific notation only; str2double by itself
            % also accepts complex values and some non-CSV number formats.
            if isempty(regexp(token, ...
                    '^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$', 'once'))
                error('%s is not a real numeric token: "%s".', fieldName, token);
            end
            value = str2double(token);
            if ~isfinite(value)
                error('%s is not a finite number: "%s".', fieldName, token);
            end
        end

        % function out = FieldChecksum(obj, X, field)
        %     % Returns the unsigned 64-bit integer sum of the first X
        %     % significant digits of field
        %     out = uint64(0);
        %     for I = 1:length(obj.(field))
        %         vec = obj.(field); val = vec(I);
        %         out = out + obj.firstSignificantDigits(val, X);
        %     end
        % end

        function out = firstSignificantDigits(~, x, X)
            % Return first X significant digits of a number as uint64
            % - x: numeric scalar
            % - X: positive integer (1..20)

            % Basic validation (manual because arguments block conflicted with method signature)
            if ~isnumeric(x) || ~isscalar(x)
                error('x must be a numeric scalar.');
            end
            if ~isscalar(X) || X ~= floor(X) || X <= 0
                error('X must be a positive integer scalar.');
            end
            if X > 20
                error('Requested significant digits exceed uint64 capacity (max 20).');
            end
            if ~isfinite(x)
                error('Input must be finite (not NaN or Inf).');
            end

            ax = abs(x);
            if ax == 0
                out = uint64(0);
                return
            end

            e = floor(log10(ax));
            scaled = ax / 10^e;        % in [1,10)
            value = floor(scaled * 10^(X-1) + 1e-12);
            out = uint64(value);
        end

        function d = nthSignificantDigit(~, x, n)
            % nthSignificantDigit  Return the nth significant decimal digit of x
            %   d = nthSignificantDigit(x,n)
            %   - x : numeric scalar
            %   - n : positive integer (1 = first significant digit)
            %   Returns integer 0..9 (type double).
            %
            %   Note: For standard double precision, requesting too many digits (>>15)
            %   will be unreliable. This function rejects n > 15 to avoid overflow/rounding issues.

            % Validate inputs
            if ~isnumeric(x) || ~isscalar(x)
                error('x must be a numeric scalar.');
            end
            % if ~issnumericint(n)
            %     error('n must be a positive integer scalar.');
            % end
            if ~isfinite(x)
                error('x must be finite (not NaN or Inf).');
            end

            % Practical safety limit for double precision
            MAX_N = 15;
            if n > MAX_N
                error('Requested digit n is too large for reliable double precision (max %d).', MAX_N);
            end

            ax = abs(x);
            if ax == 0
                d = 0;
                return
            end

            % exponent e such that ax = m * 10^e with 1 <= m < 10
            e = floor(log10(ax));
            % scaled in [1,10)
            scaled = ax / 10^e;

            % bring the desired digit into integer part
            % use a tiny epsilon to avoid floating rounding cutting down digits
            tol = 1e-12;
            shifted = floor(scaled * 10^(n-1) + tol);

            % extract the last (units) digit -> nth significant digit
            d = mod(shifted, 10);
        end

        % Small helper to check positive integer scalar
        function tf = issnumericint(v)
            tf = isnumeric(v) && isscalar(v) && v == floor(v) && v > 0;
        end

        % Canonicalisation
        function out = Fingerprint(obj)
            % Canonicalise signed zero (so that +0 and -0 are represented
            % identically)
            arc = obj.vdArcLength(:); arc(arc == 0) = 0;
            lpf = obj.vdLPF(:);       lpf(lpf == 0) = 0;
            u   = obj.vdU(:);         u(u == 0) = 0;
            res = obj.vdMaxRes(:);    res(res == 0) = 0;
            neg = obj.vnNeigs(:);
            n = uint64(numel(arc)); % entry count as uint64_t

            % Initialise empty SHA-256 cryptographic accumulator
            md = java.security.MessageDigest.getInstance('SHA-256');

            % Feed the canonical byte sequences in a fixed order
            md.update(obj.BigEndianBytes(n));
            md.update(obj.BigEndianBytes(arc));
            md.update(obj.BigEndianBytes(lpf));
            md.update(obj.BigEndianBytes(u));
            md.update(obj.BigEndianBytes(res));
            md.update(obj.BigEndianBytes(neg));

            % Finalise the 256-bit / 32-byte SHA-256 hash
            out = md.digest(); % This is a 32-element int8 array
            out = typecast(out, 'uint8'); % This is reinterpreted as a 32-element uint8 array
            out = lower(reshape(dec2hex(out, 2).', 1, [])); % This is now a 64-element hex char array (one uint8 is two hex chars)
        end

        function bytes = BigEndianBytes(~, values)
            % Converts any Matlab numeric array into a sequence of bytes
            % with a deterministic and platform-independent byte order

            % Put every numeric type into a fixed byte order.
            [~, ~, endian] = computer; % This determines the machine's byte order
            if endian == 'L'; values = swapbytes(values); end % Convert to big-endian for consistency
            % i.e. byte order specifies memory arrangement in memory. For a hex 12 34 AB:
            % big-endian: 12 34 AB i.e. b1 b2 .. bn
            % little-endian: AB 34 12 i.e. bn ... b2 b1

            % Java byte[] corresponds to MATLAB int8. Typecast preserves the
            % underlying bits; int8(values) would perform a numeric conversion.
            % values(:) 'flattens' the array into a column vector
            bytes = typecast(values(:), 'int8'); % reinterpret cast
        end
    end
end
