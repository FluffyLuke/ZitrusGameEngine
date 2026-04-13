#version 330 core

out vec4 FragColor;

in vec2 TexCoord;

uniform sampler2D ourTexture;

void main()
{
    vec4 texColor = texture(ourTexture, TexCoord);
    
    // If the pixel is basically invisible, throw it away.
    // Otherwise these pixels will overwrite what is behind them.
    if(texColor.a < 0.05) {
        discard;
    }

    FragColor = texColor;
} 