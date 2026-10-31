# shree swami samarth #


import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from sklearn.impute import SimpleImputer
from feature_engine.outliers import Winsorizer

      # medical inventory optimitation 
df = pd.read_excel(r"E:\kd project\Medical Inventory Optimaization Dataset.xlsx")
df.head
df.tail
df.info()
df.describe()
df.rename(columns={'Typeofsales': 'Type_of_sales'}, inplace=True)
df.rename(columns={'ReturnQuantity': 'Return_Qunatity'}, inplace=True)
df.rename(columns={'RtnMRP': 'Rtn_MRP'}, inplace=True)
df.rename(columns={'DrugName': 'Drug_Name'}, inplace=True)
df.rename(columns={'SubCat': 'Sub_Cat'}, inplace=True)
df.rename(columns={'SubCat1': 'Sub_Cat1'}, inplace=True)
df.rename(columns={'Dateofbill': 'Date_of_bill'}, inplace=True)
df["Date_of_bill"] = pd.to_datetime(df["Date_of_bill"], format="%m/%d/%Y").dt.strftime("%d/%m/%y")
df['Patient_ID'] = df['Patient_ID'].astype(str)
df.isnull().sum()

mode_value_drug = df['Drug_Name'].mode()[0]
df['Drug_Name'].fillna(mode_value_drug,inplace=True)

duplicate_count = df.duplicated().sum()
print(duplicate_count)
df=df.drop_duplicates()

df.to_csv(r"E:\kd project\clean files\clean_data5.csv",index=False)
dk = pd.read_csv(r"E:\kd project\clean files\cleaned_medical_data1.csv")

sns.boxplot(dk['Quantity'])
plt.title("Before Winsorization - Total Cases")
plt.show()

Winsor = Winsorizer(
    capping_method='iqr',
    tail='both',
    fold=1.5,
    variables=['Quantity'])
dk[['Quantity']] = Winsor.fit_transform(dk[['Quantity']])
sns.boxplot(dk['Quantity'])
plt.title("After Winsorization")
plt.show()

sns.boxplot(dk['Rtn_MRP'])
plt.title("Before Winsorization ")
plt.show()

Winsor = Winsorizer(
    capping_method='quantiles',
    tail='both',
    fold=0.05,
    variables=['Rtn_MRP'])
dk[['Rtn_MRP']] = Winsor.fit_transform(dk[['Rtn_MRP']])
sns.boxplot(dk['Rtn_MRP'])
plt.title("After Winsorization")
plt.show()

Q1 = dk['Rtn_MRP'].quantile(0.25)
Q3 = dk['Rtn_MRP'].quantile(0.75)
IQR = Q3 - Q1

lower_bound = Q1 - 1.5 * IQR
upper_bound = Q3 + 1.5 * IQR

dk['replace'] = np.where(dk['Return_Quantity'] < lower_bound, lower_bound,
                 np.where(dk['Return_Quantity'] > upper_bound, upper_bound, dk['Return_Quantity']))

sns.boxplot(dk['replace'])
plt.title("Before Winsorization ")
plt.show()

dk.mean(numeric_only=True)
dk.median(numeric_only=True)
dk.mode(numeric_only=True)
dk.var(numeric_only=True)
dk.std(numeric_only=True)
dk.max(numeric_only=True)
dk.min(numeric_only=True)
dk.kurt(numeric_only=True)
dk.skew(numeric_only=True)
plt.figure(figsize=(10, 15))
sns.histplot(dk['Final_Sales'],bins=5,color='pink',kde=True,edgecolor='black')
plt.show()
plt.figure(figsize=(15, 1000))
sns.histplot(dk['Final_Sales'], bins=[0, 100, 200, 300, 400, 500], color='pink', kde=True, edgecolor='black')
plt.show()