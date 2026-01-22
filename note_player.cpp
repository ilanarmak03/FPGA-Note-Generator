#include <iostream>
#include <string>
#include <sstream>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <portaudio.h>
#include <cmath>

static double g_freq = 440.0;  
static bool g_play = false;

// ===================== AUDIO CALLBACK =====================
static int audioCallback(const void*, void* outputBuffer,
                         unsigned long framesPerBuffer,
                         const PaStreamCallbackTimeInfo*,
                         PaStreamCallbackFlags,
                         void*)
{
    float* out = (float*)outputBuffer;
    static double phase = 0.0;
    const double sampleRate = 44100.0;
    const double twoPi = 6.28318530718;

    for (unsigned long i = 0; i < framesPerBuffer; i++)
    {
        if (g_play)
        {
            // Square wave
            double val = (fmod(phase, twoPi) < M_PI) ? 0.6 : -0.6;
            out[i] = val;
            phase += (twoPi * g_freq / sampleRate);
            if (phase >= twoPi) phase -= twoPi;
        }
        else
        {
            out[i] = 0.0f;
        }
    }
    return paContinue;
}

// ===================== SERIAL PORT OPEN =====================
int openSerial(const char* port)
{
    int fd = open(port, O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd < 0) return -1;

    struct termios tty{};
    tcgetattr(fd, &tty);

    cfsetospeed(&tty, B115200);
    cfsetispeed(&tty, B115200);

    tty.c_cflag |= (CLOCAL | CREAD);   // enable receiver
    tty.c_cflag &= ~CSIZE;
    tty.c_cflag |= CS8;                // 8-bit
    tty.c_cflag &= ~PARENB;            // no parity
    tty.c_cflag &= ~CSTOPB;            // 1 stop bit
    tty.c_cflag &= ~CRTSCTS;           // no flow control

    tty.c_lflag = 0;
    tty.c_oflag = 0;
    tty.c_iflag = 0;

    tcsetattr(fd, TCSANOW, &tty);
    return fd;
}

// ===================== MAIN =====================
int main(int argc, char** argv)
{
    if (argc < 2)
    {
        std::cout << "Usage: ./note_player /dev/ttyACM0\n";
        return 1;
    }

    int fd = openSerial(argv[1]);
    if (fd < 0)
    {
        std::cerr << "Failed to open serial port.\n";
        return 1;
    }
    std::cout << "Listening on " << argv[1] << "...\n";

    // Initialize PortAudio
    Pa_Initialize();
    PaStream* stream;
    Pa_OpenDefaultStream(&stream,
                         0, 1, paFloat32,
                         44100, 256,
                         audioCallback,
                         nullptr);
    Pa_StartStream(stream);

    std::string buffer;
    char ch;

    while (true)
    {
        int n = read(fd, &ch, 1);
        if (n > 0)
        {
            if (ch == '\n')
            {
                // Process completed message
                std::cout << "Received: " << buffer << "\n";

                // Parse: NOTE OCTAVE, FREQ
                std::stringstream ss(buffer);
                std::string note;
                char accidental = ' ';
                int octave = 4;
                int freq = 440;

                // Example: A#4,440
                if (buffer.size() >= 4)
                {
                    note = buffer.substr(0,1);
                    accidental = buffer[1];
                    octave = buffer[2] - '0';

                    size_t commaPos = buffer.find(',');
                    if (commaPos != std::string::npos)
                    {
                        freq = std::stoi(buffer.substr(commaPos+1));
                    }

                    g_freq = freq;
                    g_play = true;

                    std::cout << "Note: " << note
                              << accidental
                              << octave
                              << " | freq=" << freq << " Hz\n";
                }

                buffer.clear();
            }
            else if (ch != '\r')
            {
                buffer.push_back(ch);
            }
        }

        usleep(1000); // relax CPU
    }

    // Cleanup
    Pa_StopStream(stream);
    Pa_CloseStream(stream);
    Pa_Terminate();

    close(fd);
    return 0;
}

