# Virtual machine creator

The following scripts will aid in creating virtual machines for the tests cases in this document.

### The scripts will:
1. Download a Ubuntu 16.04 cloud image 
2. Create a temporarly VM using tthe cloud image that was downloaded
3. Download and install testing software to this VM
4. Undefine the temporarly VM leaving the modified image in place
5. **y_create_image_from_backing.sh** can then be used to provision new VM using the backing image that was created

### Example usage:
>**NOTE:**
>The backing image is only created once. Subsequent VM's are created using this backing image

##### To create the backing image, run the followng script  
```
./x_create_backing_image.sh
```

##### To create additional VM's using the backing image, run the followng script  
```
./y_create_image_from_backing.sh
```
