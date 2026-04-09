convert_freq_to_wavelength <- function(frequency_cm) {
  # Convert frequency in cm^-1 to wavelength in cm
  wavelength_cm <- 1 / frequency_cm
  
  # Convert wavelength from cm to nanometers (1 cm = 1e7 nm)
  wavelength_nm <- wavelength_cm * 1e7
  
  # output result
  return(wavelength_nm)
}

# Example usage:
frequency_cm <- 2200  # Example frequency in cm^-1
wavelength_nm <- convert_freq_to_wavelength(frequency_cm)
print(wavelength_nm)
