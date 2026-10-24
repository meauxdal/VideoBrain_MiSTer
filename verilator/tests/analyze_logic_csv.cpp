// Streaming extraction for Sean Riddle's Logic 1/2 CSV captures.
// Times are integer picoseconds; preserve the 62.5 ns and 80 ns grids.
// Output is measurement data, not an assertion of original-machine intent.
#include <array>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
using I = int64_t;
struct Track {
  I last=-1; unsigned initial=0, req_seen=0, dma_seen=0; unsigned changes=0;
};
static I timestamp(const std::string& s, size_t& pos) {
  I whole=0, frac=0; int digits=0;
  while(pos<s.size() && s[pos]!='.' && s[pos]!=',') whole=10*whole+s[pos++]-'0';
  if(pos<s.size() && s[pos]=='.') {
    ++pos;
    while(pos<s.size() && s[pos]!=',') {
      if(digits<12) frac=10*frac+s[pos]-'0';
      ++digits; ++pos;
    }
  }
  while(digits++<12) frac*=10;
  return whole*1000000000000LL+frac;
}
int main(int argc, char** argv) {
  try {
    if(argc!=3) throw std::runtime_error("usage: analyze_logic_csv input.csv output-prefix");
    std::ifstream in(argv[1]); if(!in) throw std::runtime_error("cannot open input");
    std::string prefix=argv[2], line; std::getline(in,line);
    bool bus=line.find("romc0")!=std::string::npos;
    const int n=bus?16:8, xtal=bus?0:1, phi=bus?1:2;
    std::ofstream gaps(prefix+"-gaps.csv"), events(prefix+"-events.csv"), hist(prefix+"-hist.csv"), meta(prefix+"-meta.txt"), cycles, io;
    if(!gaps || !events || !hist || !meta) throw std::runtime_error("cannot open output files");
    gaps<<"channel,edge,start_ps,end_ps,duration_ps,initial_state,final_state,request_codes_seen,dma_levels_seen,sideband_changes\n";
    events<<"time_ps,state,changed\n";
    hist<<"channel,kind,edge,duration_ps,count\n";
    if(bus) { cycles.open(prefix+"-cycles.csv"); cycles<<"start_ps,end_ps,romc,data_end,data_write_rise,phi_falls,xtal_falls,max_phi_gap_ps,romc_changes\n"; }
    else { io.open(prefix+"-io.csv"); io<<"start_ps,end_ps,end_level,phi_falls,xtal_falls,max_phi_gap_ps\n"; }
    std::array<std::array<Track,2>,3> track{};
    std::array<I,3> last_change{{-1,-1,-1}};
    std::map<std::array<I,4>,uint64_t> counts;
    std::array<uint64_t,16> transitions{};
    I previous_t=-1, reset_start=-1, active_ps=0, cycle_start=-1, max_phi_gap=0;
    uint64_t rows=0, duplicates=0, off_grid=0, valid_rows=0;
    unsigned previous=0, cycle_phi=0, cycle_xtal=0, romc_changes=0, data_rise=0;
    I io_start=-1, io_gap=0; uint64_t io_phi=0, io_xtal=0;
    const I grid=bus?62500:80000;
    while(std::getline(in,line)) {
      if(line.empty() || line[0]=='\r') continue;
      size_t pos=0; I t=timestamp(line,pos); unsigned state=0;
      for(int ch=0; ch<n; ++ch) {
        if(pos>=line.size() || line[pos++]!=',') throw std::runtime_error("bad column separator");
        while(pos<line.size() && line[pos]==' ') ++pos;
        if(pos>=line.size() || (line[pos]!='0' && line[pos]!='1')) throw std::runtime_error("nonbinary channel");
        state|=unsigned(line[pos++]-'0')<<ch;
      }
      if(t<previous_t) throw std::runtime_error("nonmonotonic time");
      if(t%grid) ++off_grid;
      ++rows; if(t==previous_t) ++duplicates;
      unsigned changed=rows==1?0:state^previous;
      for(int ch=0; ch<n; ++ch) if(changed&(1u<<ch)) ++transitions[ch];
      bool active=bus || (state&8), was_active=bus || (previous&8);
      if(active && (reset_start<0)) reset_start=t;
      if(!active && reset_start>=0) { active_ps+=t-reset_start; meta<<"reset_high_ps "<<reset_start<<" "<<t<<"\n"; reset_start=-1; }
      if(rows==1 || (!bus && (changed&8))) {
        for(auto& channel:track) for(auto& x:channel) x=Track{};
        last_change.fill(-1);
        io_start=-1; io_phi=io_xtal=0; io_gap=0;
      }
      unsigned side_mask=bus?0xfffc:0xf8;
      if(rows==1 || (changed&side_mask)) events<<t<<','<<state<<','<<changed<<'\n';
      if(active && was_active) {
        ++valid_rows;
        unsigned req=bus?0:(state>>5)&3, dma=bus?0:(state>>4)&1;
        for(int ch=0; ch<(bus?2:3); ++ch) {
          for(auto& x:track[ch]) { x.req_seen|=1u<<req; x.dma_seen|=1u<<dma; if(changed&side_mask) ++x.changes; }
          if(changed&(1u<<ch)) {
            unsigned edge=(state>>ch)&1;
            if(last_change[ch]>=0) ++counts[{ch,0,edge,t-last_change[ch]}];
            last_change[ch]=t;
            Track& x=track[ch][edge];
            if(x.last>=0) {
              I delta=t-x.last; ++counts[{ch,1,edge,delta}];
              if(ch==phi) { max_phi_gap=std::max(max_phi_gap,delta); io_gap=std::max(io_gap,delta); }
              // >0.8 us cleanly separates a normal 0.5 us same-edge period.
              if(delta>800000) gaps<<ch<<','<<edge<<','<<x.last<<','<<t<<','<<delta<<','<<x.initial<<','<<state<<','<<x.req_seen<<','<<x.dma_seen<<','<<x.changes<<'\n';
            }
            x={t,state,1u<<req,1u<<dma,0};
          }
        }
      }
      if(!bus && active && was_active) {
        if((changed&(1u<<phi)) && !(state&(1u<<phi))) ++io_phi;
        if((changed&(1u<<xtal)) && !(state&(1u<<xtal))) ++io_xtal;
        if(changed&128) {
          if(io_start>=0) io<<io_start<<','<<t<<','<<((state>>7)&1)<<','<<io_phi<<','<<io_xtal<<','<<io_gap<<'\n';
          io_start=t; io_phi=io_xtal=0; io_gap=0;
        }
      }
      if(bus) {
        if(changed&(1u<<phi) && !(state&(1u<<phi))) ++cycle_phi;
        if(changed&(1u<<xtal) && !(state&(1u<<xtal))) ++cycle_xtal;
        if(changed&0xf8) ++romc_changes;
        if(changed&4) {
          if(state&4) data_rise=(state>>8)&255;
          else {
            if(cycle_start>=0) cycles<<cycle_start<<','<<t<<','<<((previous>>3)&31)<<','<<((previous>>8)&255)<<','<<data_rise<<','<<cycle_phi<<','<<cycle_xtal<<','<<max_phi_gap<<','<<romc_changes<<'\n';
            cycle_start=t; cycle_phi=cycle_xtal=romc_changes=0; max_phi_gap=0;
          }
        }
      }
      previous=state; previous_t=t;
      if(rows%10000000==0) std::cerr<<argv[1]<<": "<<rows<<" rows, "<<double(t)/1e12<<" s\n";
    }
    if(reset_start>=0) { active_ps+=previous_t-reset_start; meta<<(bus?"analysis_span_ps ":"reset_high_ps ")<<reset_start<<" "<<previous_t<<"\n"; }
    for(auto const& [k,v]:counts) hist<<k[0]<<','<<k[1]<<','<<k[2]<<','<<k[3]<<','<<v<<'\n';
    meta<<"input "<<argv[1]<<"\nformat "<<(bus?"Logic1_bus":"Logic2_requests")<<"\nrows "<<rows<<"\nlast_ps "<<previous_t<<"\nactive_ps "<<active_ps<<"\nvalid_rows "<<valid_rows<<"\nduplicate_times "<<duplicates<<"\noff_grid "<<off_grid<<'\n';
    for(int ch=0; ch<n; ++ch) meta<<"transitions "<<ch<<" "<<transitions[ch]<<'\n';
    std::cout<<prefix<<": "<<rows<<" rows, "<<double(previous_t)/1e12<<" s\n";
  } catch(std::exception const& e) { std::cerr<<e.what()<<'\n'; return 1; }
}
