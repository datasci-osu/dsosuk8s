After spinning up new JH instance with the -bpp build will need to run the following to complete
supported applications installs.

Will need to install Quast after JH install. 
    hubpip install quast

For MetaEuk do:
    mkdir src
    cd src
    git clone https://github.com/soedinglab/metaeuk.git .
    mkdir build
    cd build
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=. ..
    make
    make install
    mv bin/metaeuk /home/.hub_local/bin/.
