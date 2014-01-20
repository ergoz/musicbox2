#include <stdio.h>
#include <math.h>
#include <string>
#include <valarray>
#include <vector>

const char input_fname[] = "C:\\MUSIC\\WORK\\musicbox\\musicbox2.it";
const char output_fname[] = "C:\\MUSIC\\WORK\\musicbox\\musicbox2.asm";

const int global_transpose=0;

const int patcmd_pause = 0xCC;
const int patcmd_note = 0xCD;
const int patcmd_notelen = 0x7C;
const int patcmd_skew = 0x6C;
const int patcmd_vol = 0xBC;
const int patcmd_endpattern = 0;

using namespace std;

class MessageError
{
public:
    MessageError(const string& s): msg(s) {}
    const string& get_error_message(void) const { return msg; }
private:
    string msg;
};

struct IT_PATTERN_NOTE
{
    bool set_note;
    unsigned char note;
    bool set_instrument;
    unsigned char instrument;
    bool set_vol_panning;
    unsigned char vol_panning;
    bool set_command;
    unsigned char command;
    unsigned char command_value;
};

// Instrument representation is truncated in this program, we don't
// need the entire instrument data here
struct ENVELOPE_POINT
{
    unsigned char y;
    unsigned short tick;

    // Comparison operator for sorting
    bool operator<(const ENVELOPE_POINT& a) const
    {
        if(y < a.y)
            return true;
        else if(y>a.y)
            return false;
        if(tick < a.tick)
            return true;
        return false;
    }
};

struct ENVELOPE
{
    vector<ENVELOPE_POINT> envelope;
    bool loop_on;
    unsigned short lpb;
    unsigned short lpe;

    // Comparison operator for sorting
    bool operator<(const ENVELOPE& a) const;
};

struct IT_INSTRUMENT
{
    char name[26];
    ENVELOPE pitch_envelope;
};

bool ENVELOPE::operator<(const ENVELOPE& a) const
{
    int i = 0;
    while(i<envelope.size() && i<a.envelope.size())
    {
        if(envelope[i] < a.envelope[i])
            return true;
        else if(a.envelope[i] < envelope[i])
            return false;
    }
    // Envelopes are equal to their length. Now if their length
    // is different, the longer one is greater
    if(envelope.size() < a.envelope.size())
        return true;
    else if(envelope.size() > a.envelope.size())
        return false;
    // Envelopes are fully equal, check if they have loops
    if(!loop_on && a.loop_on)
        return true; // The one which has no loop is smaller
    else if(!loop_on && !a.loop_on)
        return false; // both have no loops = equal
    // Both have loops
    if(lpb < a.lpb)
        return true;
    else if(lpb > a.lpb)
        return false;
    else if(lpe < a.lpe)
        return true;
    // Equal or greater
    return false;
}

void load_it_instrument(FILE* fs, unsigned offset, IT_INSTRUMENT& instr)
{
    // Read the instrument name
    if(fseek(fs,offset+0x20,SEEK_SET))
        throw MessageError("File seek error");
    if(fread(instr.name,1,26,fs)!=26)
        throw MessageError("File read error");
    // Read pitch envelope (for making ornaments)
    if(fseek(fs,offset+0x1D4,SEEK_SET))
        throw MessageError("File seek error");
    {
        unsigned char buf[81];
        if(fread(buf,1,81,fs)!=81)
            throw MessageError("File read error");
        if(buf[0] & 0x01)
        {
            // Envelope on, transfer it
            instr.pitch_envelope.loop_on = (buf[0] & 0x02) != 0;
            instr.pitch_envelope.lpb= buf[2];
            instr.pitch_envelope.lpe = buf[3];
            instr.pitch_envelope.envelope.resize(buf[1]);
            for(int i=0; i<buf[1]; i++)
            {
                instr.pitch_envelope.envelope[i].y = buf[6+i*3];
                instr.pitch_envelope.envelope[i].tick = buf[6+i*3+1] + 256*buf[6+i*3+2];
            }
        }
        else
        {
            instr.pitch_envelope.envelope.clear();
            instr.pitch_envelope.loop_on = false;
            instr.pitch_envelope.lpb = 0;
            instr.pitch_envelope.lpe = 0;
        }
    }
}

void load_it_pattern(FILE* fs, unsigned offset, vector<vector<IT_PATTERN_NOTE> >&pattern)
{
    if(fseek(fs,offset+2,SEEK_SET))
        throw MessageError("File seek error");
    unsigned short nrows;
    if(fread(&nrows,2,1,fs)!=1)
        throw MessageError("File read error");
    if(fseek(fs,4,SEEK_CUR))
        throw MessageError("File seek error");
    pattern.resize(nrows);
    IT_PATTERN_NOTE arow[64];
    // Initial state for all channels is a pause
    for(int ch=0; ch<5; ch++)
    {
        arow[ch].set_note = true;
        arow[ch].note = 254;
        arow[ch].set_instrument = false;
        arow[ch].set_command = false;
        arow[ch].set_vol_panning = false;
    }
    unsigned char mask_variables[64];
    fill(mask_variables,mask_variables+64,0);
    int currow = 0;
    while(currow<nrows)
    {
        // IT pattern unpacking
        unsigned char chvar;
        if(fread(&chvar,1,1,fs)!=1)
            throw MessageError("File read error");
        if(chvar==0)
        {
            pattern[currow].resize(5);
            // End of row, convert data
            for(int ch=0; ch<5; ch++) // Only process first 5 channels
            {
                pattern[currow][ch] = arow[ch];
                arow[ch].set_note = false;
                arow[ch].set_instrument = false;
                arow[ch].set_vol_panning = false;
                arow[ch].set_command = false;
            }
            currow++;
        }
        else
        {
            unsigned char ch = (chvar-1)&63;
            if(chvar & 128)
            {
                if(fread(mask_variables+ch,1,1,fs)!=1)
                    throw MessageError("File read error");
            }
            if(mask_variables[ch] & 1)
            {
                if(fread(&arow[ch].note,1,1,fs)!=1)
                    throw MessageError("File read error");
            }
            if(mask_variables[ch] & 2)
            {
                if(fread(&arow[ch].instrument,1,1,fs)!=1)
                    throw MessageError("File read error");
            }
            if(mask_variables[ch] & 4)
            {
                if(fread(&arow[ch].vol_panning,1,1,fs)!=1)
                    throw MessageError("File read error");
            }
            if(mask_variables[ch] & 8)
            {
                if(fread(&arow[ch].command,1,1,fs)!=1)
                    throw MessageError("File read error");
                if(fread(&arow[ch].command_value,1,1,fs)!=1)
                    throw MessageError("File read error");
            }
            arow[ch].set_note = (mask_variables[ch] & 0x11)!=0;
            arow[ch].set_instrument = (mask_variables[ch] & 0x22)!=0;
            arow[ch].set_vol_panning = (mask_variables[ch] & 0x44)!=0;
            arow[ch].set_command = (mask_variables[ch] & 0x88)!=0;
        }
    }
}

const int instr_volume[5] = {15,15,15,15,15};
const int instr_skew[5] = {0,0,2,6,11};

void conv_wr_pattern(FILE* ft, int ipat, const vector<vector<IT_PATTERN_NOTE> >& it_rows)
{
    for(int ch=0; ch<4; ch++)
    {
        fprintf(ft,"pattern_%d_%d:\n",ipat,ch);
        int cur_notelen=-1;
        int currow = 0;
        int last_instr=-1;
        IT_PATTERN_NOTE curnote;
        curnote.set_note = true;
        curnote.note = 254;
        curnote.set_instrument = true;
        curnote.instrument = 1;
        while(currow<it_rows.size())
        {
            // Search for the next note (determine note length)
            int proberow = currow+1;
            while(proberow<it_rows.size() && !it_rows[proberow][ch].set_note)
                proberow++;
            if(proberow-currow != cur_notelen)
            {
                // new note length
                cur_notelen = proberow-currow;
                fprintf(ft,"\tretlw\tH'%02X'\n",cur_notelen+patcmd_notelen);
            }
            if(it_rows[currow][ch].set_note)
            {
                // This condition may be false in case of ???
                curnote = it_rows[currow][ch];
            }
            if(curnote.note <254)
            {
                //Play a note. Set instrument if necessary
                if(curnote.set_instrument && curnote.instrument != last_instr)
                {
                    last_instr = curnote.instrument;
                    // Set default volume and skew
                    fprintf(ft,"\tretlw\tH'%02X'\n",patcmd_vol+instr_volume[last_instr]);
                    fprintf(ft,"\tretlw\tH'%02X'\n",patcmd_skew+instr_skew[last_instr]);
                }
                int note_r_ds2 = (int)curnote.note - 69+24+global_transpose;// so that A-5 as 24
                if(note_r_ds2<0)
                {
                    note_r_ds2 = 0;
                    printf("Pattern %d, row %d, channel %d, note too low, replaced by A-3\n",ipat,currow,ch);
                }
                if(note_r_ds2 > 24+26)
                {
                    printf("Pattern %d, row %d, channel %d, note too high, replaced by B-7\n",ipat,currow,ch);
                    note_r_ds2 = 24+26;
                }
                fprintf(ft,"\tretlw\tH'%02X'\n",note_r_ds2+patcmd_note);
            }
            else
            {
                //Play a pause
                fprintf(ft,"\tretlw\tH'%02X'\n",patcmd_pause);
            }
            currow = proberow;
        }
        if(ch==0)
        {
            // Pattern end code
            fprintf(ft,"\tretlw\t0\n");
        }
    }
}

void main_try(int argc, char* argv[])
{
    FILE* fs = fopen(input_fname,"rb");
    if(!fs)
        throw MessageError("Error opening input file");

    // Check file signature
    {
        unsigned buf;
        if(fread(&buf,4,1,fs)!=1)
            throw MessageError("File read error");
        if(buf!='MPMI') // IMPM
            throw MessageError("File format error");
    }

    if(fseek(fs,0x20,SEEK_SET))
        throw MessageError("File seek error");

    // Load number of orders, instruments, samples and patterns
    unsigned short ordnum,insnum,smpnum,patnum;
    {
        unsigned short buf[4];
        if(fread(buf,2,4,fs)!=4)
            throw MessageError("File read error");
        ordnum = buf[0];
        insnum = buf[1];
        smpnum = buf[2];
        patnum = buf[3];
        if(fread(buf,2,4,fs)!=4)
            throw MessageError("File read error");
        // Check flags
        if((buf[2] & 0xC) != 0x0C)
            throw MessageError("File must use instruments and linear freq slides");
    }
    // Load speed and tempo
    unsigned char speed, tempo;
    {
        unsigned char buf[4];
        if(fread(buf,1,4,fs)!=4)
            throw MessageError("File read error");
        speed = buf[2];
        tempo = buf[3];
    }

    // Load orders
    if(fseek(fs,0xC0,SEEK_SET))
        throw MessageError("File seek error");
    valarray<unsigned char> orders(ordnum);
    if(fread(&orders[0],1,ordnum,fs)!=ordnum)
        throw MessageError("File read error");
    // Load instrument offsets
    valarray<unsigned> instrument_offsets(insnum);
    if(fread(&instrument_offsets[0],4,insnum,fs)!=insnum)
        throw MessageError("File read error");
    // Skip sample offsets, we don't parse samples
    if(fseek(fs,4*(smpnum),SEEK_CUR))
        throw MessageError("File seek error");
    // Load pattern offsets
    valarray<unsigned> pattern_offsets(patnum);
    if(fread(&pattern_offsets[0],4,patnum,fs)!=patnum)
        throw MessageError("File read error");
    // Load instruments
    vector<IT_INSTRUMENT> instruments(insnum);
    for(int i=0; i<insnum; i++)
    {
        load_it_instrument(fs,instrument_offsets[i],instruments[i]);
    }
    // Load patterns
    vector<vector<vector<IT_PATTERN_NOTE> > > patterns(patnum);
    for(int i=0; i<patnum; i++)
    {
        load_it_pattern(fs,pattern_offsets[i],patterns[i]);
    }

    // Create output file
    FILE* ft = fopen(output_fname,"w");
    fputs("posdata:\n",ft);
    for(int i=0; i<ordnum; i++)
    {
        if(orders[i]==255)
            break;
        else if(orders[i]==254)
            continue;
        for(int j=0; j<4; j++)
        {
            fprintf(ft,"\tretlw\tLOW\tpattern_%d_%d\n",orders[i],j);
            fprintf(ft,"\tretlw\tHIGH\tpattern_%d_%d\n",orders[i],j);
        }
    }
    fprintf(ft,"\tretlw\t0\n");
    fprintf(ft,"\tretlw\t0\n");

    for(int i=0; i<patnum; i++)
    {
        conv_wr_pattern(ft,i,patterns[i]);
    }

    fclose(ft);
    fclose(fs);
}

int main(int argc, char* argv[])
{
    try
    {
        main_try(argc,argv);
    }
    catch(MessageError& e)
    {
        printf("%s\n",e.get_error_message().c_str());
        return 1;
    }
    return 0;
}
