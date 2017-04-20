#for lr in 0.0001 0.00001 0.000001 0.0000001 ;
#do
#for wd in 0.001 0.0001 0.00001 0.000001 0.0000001 ;
#do
#./train_model.sh $wd 2000
#done
for bs in 100 200 500 1000 2000 5000 ;
do
./train_model.sh $bs bs$bs
done
./evaluate_model.sh 2017-03-10_0957_esat_offline_7 7_off
./evaluate_model.sh 2017-03-13_2002_same_startpos_off_ft_7 7_on
./evaluate_model.sh 2017-03-10_0957_esat_offline_6 6_off
./evaluate_model.sh 2017-03-10_1351_esat_offline_5 5_off

#done

#conclusion: 1e-05 is nice and steady, 1e-04 is faster 
# higher learning rates tend to benefit of weight decays.



