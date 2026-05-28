
#define __USE_SQUARE_BRACKETS_FOR_ELEMENT_ACCESS_OPERATOR
#include "lib/simple_fft/fft.hpp"
#include "lib/simple_fft/fft_settings.h"

#include <libserialport.h>

#include <unistd.h>
#include <stdio.h>
#include <iostream>
#include <cstring>
#include <string>
#include <cstdint>
#include <fstream>
#include <vector>
#include <cmath>
#include <complex>
#include <format>
#include <iomanip>


#define SERIAL_PORT "/dev/ttyUSB1"
#define SAMPLE_RATE 2222000.0 //Hz

const int EXPECTED_RX_BYTES = 255 * 13; // 256 * 13 bytes ("!AA:DDDDDDDD\r")


typedef double real_type;
typedef std::complex<real_type> complex_type;


char* selectAddr(uint8_t addr){
    char buffer[32];

    sprintf(buffer, "#r:%02x........", addr);

    return buffer;
}


std::string readADC(){
    char buffer[32];
    uint8_t addr = 255;
    sprintf(buffer, "#r:%02x........", addr);
    return std::string(buffer);
}



void save_raw_samples_to_csv(const int* data, int size) {
    std::ofstream file("raw_samples.csv");

    // CSV header
    file << "sample_index,value\n";

    for (int i = 0; i < size; i++) {
        file << i << "," << data[i] << "\n";
    }

    file.close();

    std::cout << "Saved " << size << " samples to raw_samples.csv" << std::endl;
}





///////////// FFT ////////////////////////////////////
void five_largest_frequencies(int sample_size, std::vector<complex_type> output){
    //Check for largest bins
    std::vector<int> max_bins = {-2, -2, -2, -2, -2};
    std::vector<double> max_magnitudes = {-1.0, -1.0, -1.0, -1.0, -1.0};
    std::vector<double> detected_frequencies = {-1.0, -1.0, -1.0, -1.0, -1.0};

    //Finds 5 largest bins
    for (int bins5 = 0; bins5 < 5; bins5++){

        int max_bin = -1;
        double max_magnitude = -1.0;
        
        // Goes trough magnitudes and finds max
        for (int i = 0; i < sample_size/2; i++){
            double magnitude = std::abs(output[i]);

            //Checks if bin have already beeen found
            bool bin_already_found = false;
            for (int used = 0; used < 5; used++){
                if (i == max_bins[used]){
                    bin_already_found = true;
                }
            }
            
            if (!bin_already_found && (magnitude > max_magnitude)){
                max_magnitude = magnitude;
                max_bin = i;
            }
        } 
        
        //Insert the found bin and magnitude
        max_bins[bins5] = max_bin;
        max_magnitudes[bins5] = max_magnitude;
        detected_frequencies[bins5] = max_bin * SAMPLE_RATE / sample_size;
    }


    //Sort by largest magnitude
    for (int i = 0; i < 5; i++){
        for (int j = i+1; j < 5; j++){
            if (max_magnitudes[j] > max_magnitudes[i]){
                double temp_magnitude = max_magnitudes[i];
                max_magnitudes[i] = max_magnitudes[j];
                max_magnitudes[j] = temp_magnitude;

                double temp_detected_frequency = detected_frequencies[i];
                detected_frequencies[i] = detected_frequencies[j];
                detected_frequencies[j] = temp_detected_frequency;

                int temp_bin = max_bins[i];
                max_bins[i] = max_bins[j];
                max_bins[j] = temp_bin;

            }
        }
    }

    for (int i = 0; i < 5; i++){
        std::cout << "Detected frequency number " << i << ": " << detected_frequencies[i] << std::endl;
    }
}


void save_to_csv(int display_bins, std::vector<double> display_magnitudes, std::vector<double> display_frequencies) {
    std::ofstream file("spectrum.csv");

    file << "frequency_hz,magnitude_db\n";

    for (int i = 1; i < display_bins; i++) {
        file << display_frequencies[i] << ","
             << display_magnitudes[i] << "\n";
    }

    file.close();
}


struct SpectrumResult {
    int display_bins;
    std::vector<double> frequencies;
    std::vector<double> magnitudes;
};



SpectrumResult spectrum_analyzer(int sample_size, std::vector<complex_type> output) {
    // Spectrum analyzer settings
    const int display_bins = 1920;
    const int fft_bins = sample_size / 2;

    // Create vectors
    std::vector<double> display_frequencies(display_bins);
    std::vector<double> display_magnitudes(display_bins);
    std::vector<double> display_magnitudes_db(display_bins);

    //Min and mac frequency
    double min_frequency = SAMPLE_RATE / sample_size;  // bin 1
    double max_frequency = SAMPLE_RATE / 2.0;          // Nyquist

    // The actual transformation into logaritmic range
    for (int log_bin_i = 0; log_bin_i < display_bins; log_bin_i++) {
        // The start and end linear bins, that will be put into a single logarithmic bin
        double log_start = double(log_bin_i) / display_bins;
        double log_end   = double(log_bin_i + 1) / display_bins;

        // The frequencies, that corresonds to these start- and end bins.
        double frequency_start = min_frequency * std::pow(max_frequency / min_frequency, log_start);
        double frequency_end =min_frequency * std::pow(max_frequency / min_frequency, log_end);

        // Convert frequency range to FFT bin range
        int bin_start = int(frequency_start * sample_size / SAMPLE_RATE);
        int bin_end   = int(frequency_end   * sample_size / SAMPLE_RATE);

        // Ensure the start and end bin is valid.
        if (bin_start < 1) {bin_start = 1;}
        if (bin_end >= fft_bins) {bin_end = fft_bins - 1;}
        if (bin_end < bin_start) {bin_end = bin_start;}


        // Find maximum magnitude inside this frequency range defined by the bins.
        double max_magnitude = 0.0;
        for (int bin = bin_start; bin <= bin_end; bin++) {
            double magnitude = std::abs(output[bin]);
            if (magnitude > max_magnitude) {
                max_magnitude = magnitude;
            }
        }
        display_magnitudes[log_bin_i] = max_magnitude;


        // Convert to log range on x axis
        double center_frequency = std::sqrt(frequency_start * frequency_end);
        display_frequencies[log_bin_i] = std::log10(center_frequency);
    }

    // Convert magnitudes to decibel
    // First: Find max magnitude for calculating the magnitude in db
    double global_max = 0.0;
    for (int i = 0; i < display_bins; i++) {
        if (display_magnitudes[i] > global_max) {
            global_max = display_magnitudes[i];
        }
    }

    // Second: Find value to shift magnitudes into postive values only (aka prepare for fpga)
    double temp_max_mag = 0.0;
    for (int i = 0; i < display_bins; i++) {
        double magnitude = display_magnitudes[i];
        double magnitude_db = 20.0 * std::log10((magnitude) + 1e-12);
        if (temp_max_mag > magnitude_db){
            temp_max_mag = magnitude_db;
        }
    }

    // Third: Save the magnitudes in db
    for (int i = 0; i < display_bins; i++) {
        double magnitude = display_magnitudes[i];
        double magnitude_db = 20.0 * std::log10((magnitude) + 1e-12) - temp_max_mag;
        display_magnitudes_db[i] = int(magnitude_db);
    }

    return {display_bins, display_frequencies, display_magnitudes_db};
}
/////// FFT////////////////////////





inline bool serial_write(sp_port* port, const std::string& s){
    int written = sp_blocking_write( port, s.data(), s.size(), 20);

    return written == (int)s.size();
}



bool read_Qlink_block(sp_port* serial, int *output){
  bool sucess = true;


  std::stringstream tx_stream;
  for (int addr = 1; addr < 256; ++addr) {
    tx_stream << "#r:" << std::setfill('0') << std::setw(2) << std::uppercase << std::hex << addr  << ".........."; // 10 characters of padding
  }
  std::string tx_buffer = tx_stream.str();

  serial_write(serial, tx_buffer); // skriver #r

    // Allocate buffer for reading back the response block
  std::vector<char> rx_buffer(EXPECTED_RX_BYTES, 0);
  int total_bytes_read = 0;
    
    // Read loop ensures we swallow the exact entire block before stopping
  while (total_bytes_read < EXPECTED_RX_BYTES) {
    int bytes_read = sp_nonblocking_read( serial, rx_buffer.data() + total_bytes_read, EXPECTED_RX_BYTES - total_bytes_read );
    if (bytes_read < 0) {
        std::cerr << "Read error occurred.\n";
        break;
    }

    if (bytes_read == 0)
        continue;

    total_bytes_read += bytes_read;
  }

  // std::cout << "Her test " << std::endl;
    char block[255*4];
    char received[16];

    memset(received, 0, sizeof(received));
    memset(block, 0, sizeof(block));


  int out_index = 0;


  for (int k = 0; k < total_bytes_read; k += 13) {

    // Validate packet
    if (rx_buffer[k] != '!' || rx_buffer[k + 3] != ':')
        continue;

    output[out_index++] = std::stoi( std::string{rx_buffer[k+4], rx_buffer[k+5]}, nullptr, 16);
    output[out_index++] = std::stoi( std::string{rx_buffer[k+6], rx_buffer[k+7]}, nullptr, 16 );
    output[out_index++] = std::stoi( std::string{rx_buffer[k+8], rx_buffer[k+9]}, nullptr, 16 );
    output[out_index++] = std::stoi( std::string{rx_buffer[k+10], rx_buffer[k+11]}, nullptr, 16 );

  // std::cout << "output3 " << output[out_index]<< std::endl;
  }

  return sucess;
}






bool read_Qlink_zero(sp_port* serial, int *output){
  bool sucess = false;
  uint8_t addrToRead = 0;
  // char command[32];
  char command[120];

  snprintf(command, sizeof(command), "#r:%02x.................", addrToRead);
  // std::cout << "sending " << command << std::endl;
  serial_write(serial, command); // skriver #r
  
  char received[16];
  memset(received, 0, sizeof(received));
  
  // int bytesRead = sp_nonblocking_read(serial, received, 16);
  int bytesRead = sp_blocking_read(serial, received, 16, 20);

  int loopCnt = 0;
  while(bytesRead < 12){
    loopCnt++;
    bytesRead = sp_nonblocking_read(serial, received, 16);
  }


  received[bytesRead] = '\0';

  // remove header --> eg from !FF:2B2B2A2B to 2B2B2A2B
  output[3] = std::stoi(std::string{received[4],  received[5]},  nullptr, 16); 
  output[2] = std::stoi(std::string{received[6],  received[7]},  nullptr, 16);
  output[1] = std::stoi(std::string{received[8],  received[9]},  nullptr, 16);
  output[0] = std::stoi(std::string{received[10], received[11]}, nullptr, 16);

  return sucess;
}

void write_Qlink_8(sp_port* serial, int addrToWrite, int value){
  
  char command[32];
  snprintf(command, sizeof(command), "#w:%02x000000%02x", addrToWrite, value);
  sp_blocking_write(serial, command, 15, 1);
}


void write_Qlink_32(sp_port* serial, int addrToWrite, int value[]){

  char command[32];
  snprintf(command, sizeof(command), "#w:%02x%02x%02x%02x%02x", addrToWrite, value[3],value[2],value[1],value[0]);
  sp_blocking_write(serial, command, 15, 1);
}
/////////////////////////////////////////



enum StateMachine {
  INIT, //0
  READ_BYTES, //1
  WRITE_BYTES, // 2
  DONE            //
}; 





int main(){

  // Serial object
  sp_port* serial = nullptr;

  // Open serial port
  if (sp_get_port_by_name(SERIAL_PORT, &serial) != SP_OK) {
    std::cerr << "failed to find serial port\n";
    return -1;
  }

  if (sp_open(serial, SP_MODE_READ_WRITE) != SP_OK) {
    std::cerr << "failed to open serial port\n";
    return -1;
  }

  sp_set_baudrate(serial, 3000000);
  sp_set_bits(serial, 8);
  sp_set_parity(serial, SP_PARITY_NONE);
  sp_set_stopbits(serial, 1);
  sp_set_flowcontrol(serial, SP_FLOWCONTROL_NONE);

  sp_flush(serial, SP_BUF_BOTH);

  std::cout << "successful connection to " << SERIAL_PORT << std::endl;

  int maxIterator = 0;
  int readLast = 0;

  int addr_zero = 0;
  int addr_zero_value = 1;

  int large_array[32768];
  int large_array_cnt = 0;
  memset(large_array, 0, sizeof(large_array));

  bool fft_done = false;
  int fft_data[2048]; // data en er 1920, men vi sender 1024*2
  memset(fft_data, 0, sizeof(fft_data));

  int fft_transmitted = 0;
  int chunk_index = 0;

  StateMachine state = INIT;
  while (true) {

    // std::cout << "State " << state << std::endl;
    switch (state)
    {

    case INIT:
      {
        addr_zero_value = 1;
        addr_zero = 0;

        large_array_cnt = 0;
        memset(large_array, 0, sizeof(large_array));

        fft_done = false;
        memset(fft_data, 0, sizeof(fft_data));
        fft_transmitted = 0;
        chunk_index = 0;

        int received[15];
        bool sucess = read_Qlink_zero(serial, received);
        addr_zero_value = received[0];
        // std::cout << "FPGA addr0 = " << addr_zero_value << std::endl;


        if(addr_zero_value == 1){
          state = READ_BYTES;
        }
        
        break;
      }

    case READ_BYTES: // 1
      {
        // if % 2 == 1 på addr 0 && 
        // addr_zero_value = read_Qlink(serial, addr_zero);
        int received[15];
        bool sucess = read_Qlink_zero(serial, received);
        addr_zero_value = received[0];


        // std::cout << "FPGA addr0 = " << addr_zero_value << std::endl;
        if (addr_zero_value % 2 == 1) { // computer read

          int received_block[255 * 4];
          bool sucess = read_Qlink_block(serial, received_block);
          if (sucess) {

            for (int j = 0; j < 255 * 4; j++) {

              large_array[large_array_cnt] = received_block[j];

              // std::cout << "Bytes read at " << large_array_cnt << "   value: " << received_block[j] << std::endl;

              large_array_cnt++;
              if (large_array_cnt >= 32768)
                    break;
              }
          }
          // std::cout << "readbytes addr_zero_value " << addr_zero_value << std::endl;
          if (large_array_cnt < 32767) {
            addr_zero_value++;
            write_Qlink_8(serial, addr_zero, addr_zero_value);
            // std::cout << "Bytes read set addr_zero_value " << addr_zero_value << std::endl;
          }
        }
        else{ // computer wait for fpga to fill qlink bram
            //NOP operation
            // std::cout << "IT IS IN ELSE IN READ_BYTES" << std::endl;
        }

        if(large_array_cnt > 32767) { 
          // read all 32768 bytes so change state
          // save_raw_samples_to_csv(large_array, 32768);

          int received[15];
          bool sucess = read_Qlink_zero(serial, received);
          addr_zero_value = received[0];
          // std::cout << "FPGA addr0 test = " << addr_zero_value << std::endl;
          // std::cout << "IT IS IN READ_BYTES end.............................................." << std::endl;
          state = WRITE_BYTES;
        }

        break;
      }

    case WRITE_BYTES:
      {
        if (fft_done) {
          // flyt de første ca 1024 byte over
          // increase addresse 0 value

          int received[15];
          bool sucess = read_Qlink_zero(serial, received);
          addr_zero_value = received[0];
          // std::cout << "FPGA addr0 = " << addr_zero_value << std::endl;

          if (addr_zero_value % 2 == 1) { // computer write
           int currentMax = 0;
            for(int i = 0; i < 255; i++){

              int base = chunk_index * 4;
              // fft_data
              int fourBytes[4] = { fft_data[base], fft_data[base + 1], fft_data[base + 2], fft_data[base + 3] };

              // std::cout << "write bytes round " << i << "  " << fft_data[base] << std::endl;
              // std::cout << "write bytes round " << i << "  " << fft_data[base+1] << std::endl;
              // std::cout << "write bytes round " << i << "  " << fft_data[base+2] << std::endl;
              // std::cout << "write bytes round " << i << "  " << fft_data[base+3] << std::endl;
              currentMax = base+3;

              write_Qlink_32(serial, i+1, fourBytes);

              chunk_index++;
            } 

            // std::cout << "max iterator for fft_data "  << currentMax<< std::endl;
            addr_zero_value++;
            // std::cout << "Bytes write set addr_zero_value " << addr_zero_value << std::endl;
            write_Qlink_8(serial, addr_zero, addr_zero_value);
            fft_transmitted++;
          }
          else{ // fpga read
            //NOP operation
            // std::cout << "IT IS IN ELSE IN WRITE_BYTES" << std::endl;
          } 

          if (fft_transmitted >= 2) { // skift til reset
            // std::cout << "FFT transmitted " << std::endl;
            std::cout << "   " << std::endl;

            state = DONE;
            // state = INIT;
          }

        }
        else{ // regn fft
          
          const int sample_size = 32768;

          // test array
          std::vector<real_type> input_samples(sample_size); //number of samples
          std::vector<complex_type> output(sample_size);

          for(int k = 0; k < 32768; k++){
            input_samples[k] = large_array[k];
          }

          const char* error = nullptr;
          bool success = simple_fft::FFT(input_samples, output, sample_size, error);
          if(!success){std::cout << "FFT failed" << std::endl;return 0;}

          ///////////////////////////////////////
          // Check for largest bins
          five_largest_frequencies(sample_size, output);


          ///////////////////////////////////////
          // Spectrum analyzer
          SpectrumResult spectrum = spectrum_analyzer(sample_size, output); // Relevant values are in spectrum.magnitudes

          
          ///////////////////////////////////////
          // Save spectrum to CSV file
          save_to_csv(spectrum.display_bins, spectrum.magnitudes, spectrum.frequencies);
          
          memset(fft_data, 0, sizeof(fft_data));
          for (int i = 0; i < 1920; i++) {
            fft_data[i] = spectrum.magnitudes[i]; // 0–255 PWM
          }
          
          fft_done = true;
        }

        break;
    
      }
      case DONE:
        // NOP operation
        // int val = 255;
          int received[15];
          bool sucess = read_Qlink_zero(serial, received);
          addr_zero_value = received[0];
          // std::cout << "FPGA addr0 donedone = " << addr_zero_value << std::endl;
            //
            //
            // std::cout << "Bytes write set addr_zero_value " << val << std::endl;
            // write_Qlink_8(serial, addr_zero, val);
          state = INIT;
      break;
   } 
    
  }
  sp_close(serial);
  sp_free_port(serial);

    return 0;
}
