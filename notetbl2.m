fs = 2e6/72;

notes = -24:26;
f = zeros(size(notes));
d = zeros(size(notes));
fa = zeros(size(notes));
ndifs = zeros(size(notes));
for i=1:length(notes)
    f(i) = 440*2^(notes(i)/12);
    k = round(fs/f(i));
    fa(i) = fs/k;
    na = 12*log2(fa(i)/440);
    ndifs(i) = na-notes(i);
    d(i) = k;
    fprintf('%10.1f    %10.1f    %3d   %4.2f\n',f(i),fa(i),notes(i),ndifs(i));
end
plot(ndifs);
ylim([-0.5 0.5]);
 fprintf('\n\n');
 for i=1:length(notes)
     fprintf('\tretlw\tH''%02X''\n',d(i));
 end
