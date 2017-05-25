docker rm $(docker ps -a -q)
docker run -v C:\Users\cristym\Documents\Programs\SW:/home -w "/home" mrcoz/rp6 perl6 standardWorkConverter.p6