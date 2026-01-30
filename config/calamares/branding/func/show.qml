import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1b2b34"

            Text {
                anchors.centerIn: parent
                text: "Func Linux\n\nFunction First Linux\nCLI-first Developer Distro"
                color: "#c0c5ce"
                font.pixelSize: 24
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1b2b34"

            Text {
                anchors.centerIn: parent
                text: "Utvecklingsverktyg\n\n• Git & GitHub CLI\n• Python, Node.js, GCC\n• Docker\n• Vim, Tmux"
                color: "#c0c5ce"
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1b2b34"

            Text {
                anchors.centerIn: parent
                text: "AI & Google Integration\n\n• Gemini CLI\n• Ollama (lokal LLM)\n• Google Drive auto-mount\n• PyTorch & Transformers"
                color: "#c0c5ce"
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1b2b34"

            Text {
                anchors.centerIn: parent
                text: "Kali-inspirerade verktyg\n\n• Nmap, Wireshark, Metasploit\n• Burp Suite, SQLMap\n• Aircrack-ng, Hashcat\n• OSINT & Forensik"
                color: "#c0c5ce"
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }
}
