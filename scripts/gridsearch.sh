for lr in 0.001 0.0001 0.00001 0.000001 0.0000001 ;
do
for wd in 0.001 0.0001 0.00001 0.000001 0.0000001 ;
do
./train_model.sh $lr $wd
done
done

#conclusion: 1e-05 is nice and steady, 1e-04 is faster 
# higher learning rates tend to benefit of weight decays.



