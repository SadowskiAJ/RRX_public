clear, clc, close all

% Builds RRX_data objects
hexes = dir('Anonymised\*.txt');
tot = length(hexes);
assert(tot > 0, 'No submission files found in Anonymised.');
RRX_data = createArray(tot, 1, 'cRRX_Object');

for I = 1:tot
    fprintf(['Processing ',num2str(I),' of ',num2str(tot),': ',hexes(I).name,'\n']);
    % The constructor opens/closes the file and reports read failures.
    RRX_data(I) = cRRX_Object(fullfile(hexes(I).folder, hexes(I).name));
end
disp('');

% De-duplication
unique_MNA  = deduplicate(RRX_data, 'MNA');  disp(['MNA:  ',num2str(length(unique_MNA)) ,' unique fingerprints.']);
unique_GNA1 = deduplicate(RRX_data, 'GNA1'); disp(['GNA1: ',num2str(length(unique_GNA1)),' unique fingerprints.']);
unique_GNA2 = deduplicate(RRX_data, 'GNA2'); disp(['GNA2: ',num2str(length(unique_GNA2)),' unique fingerprints.']);
unique_GNA3 = deduplicate(RRX_data, 'GNA3'); disp(['GNA3: ',num2str(length(unique_GNA3)),' unique fingerprints.']);
unique_ALL  = deduplicate(RRX_data, 'ALL');  disp(['ALL:  ',num2str(length(unique_ALL)) ,' unique fingerprints.']);

function dict = deduplicate(RRX_data, what)
    % Each value is a variable-length uint64 vector of submission indices.
    dict = containers.Map('KeyType', 'char', 'ValueType', 'any');

    % Dictionary selector to fingerprint field path
    switch what
        case 'MNA',  fld = 'cMNA_Block.sFingerprint';
        case 'GNA1', fld = 'cGNA1_Block.sFingerprint';
        case 'GNA2', fld = 'cGNA2_Block.sFingerprint';
        case 'GNA3', fld = 'cGNA3_Block.sFingerprint';
        case 'ALL',  fld = 'sSubmissionFingerprint';
        otherwise, error('Unknown ''what'' value.');
    end

    parts = strsplit(fld, '.');
    for I = 1:numel(RRX_data)        
        val = RRX_data(I).(parts{1}); % Get value at dotted path
        for p = 2:numel(parts); val = val.(parts{p}); end       
        key = char(val); % Ensure char key
        if dict.isKey(key)
            dict(key) = [dict(key), uint64(I)];
        else
            dict(key) = uint64(I);
        end
    end
end
