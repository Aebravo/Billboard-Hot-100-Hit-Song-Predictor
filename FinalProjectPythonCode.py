import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn import tree
from sklearn.tree import DecisionTreeClassifier, export_graphviz
from sklearn.model_selection import train_test_split
from sklearn.tree import export_graphviz
from sklearn.metrics import accuracy_score
from matplotlib import pyplot as plt
import graphviz
import io
from scipy import misc
from sklearn.metrics import confusion_matrix
from sklearn.svm import SVC

hits = pd.read_csv("/Users/angelobravo/Downloads/CS 451 Final Project Code /billboard100_with_songscores.csv", sep = ',', error_bad_lines=False, engine = 'c')
non_hits = pd.read_csv("/Users/angelobravo/Downloads/CS 451 Final Project Code /billboard_songscores.csv", sep = ',', error_bad_lines=False, engine = 'c')

hitsdf = hits.iloc[:,:]
pre_non_hitsdf = non_hits.iloc[:,:]

pre_non_hitsdf2 = pre_non_hitsdf.loc[pre_non_hitsdf['billboard_hit'] == 0]

hitstrain, hitstest, _, _ = train_test_split(hitsdf, hitsdf, test_size=0.1,random_state = 100)

non_hitsdf = pre_non_hitsdf2.sample(n=hitsdf.shape[0], random_state=100)
non_hitstrain, non_hitstest, _, _ = train_test_split(non_hitsdf, non_hitsdf,test_size=0.1, random_state=100)

full_train = pd.concat([hitstrain, non_hitstrain], axis=0).reset_index(drop=True)
full_test = pd.concat([hitstest, non_hitstest], axis=0).reset_index(drop=True)

full_train['metric'].fillna(0, inplace=True)
full_test['metric'].fillna(0, inplace=True)


def modeldf(df, subset_cols):
    df = df.dropna(subset=['explicit', 'mode', 'key','time_signature','duration_ms', 'acousticness', 'danceability','energy','instrumentalness', 'liveliness', 'loudness', 'speechiness','tempo','valence', 'billboard_hit'], how = 'any')
    explicit = pd.get_dummies(df['explicit'], prefix ='explicit')
    mode = pd.get_dummies(df['mode'], prefix='mode')
    key = pd.get_dummies(df['key'], prefix='key')
    time_signature = pd.get_dummies(df['time_signature'],prefix='time_signature')
    df = pd.concat([df[subset_cols], explicit, mode, key, time_signature],axis=1)
    return df

subset_cols = ['track_title', 'duration_ms', 'acousticness', 'danceability','energy', 'instrumentalness', 'liveliness', 'loudness', 'speechiness','tempo', 'valence', 'billboard_hit']
full_train = modeldf(full_train, subset_cols=subset_cols)
full_test = modeldf(full_test, subset_cols=subset_cols)

c = DecisionTreeClassifier(min_samples_split = 100)
features = full_train.columns.difference(['track_title','artist_title','billboard_hit'])
X_train = full_train[features]
Y_train = full_train['billboard_hit'].apply(np.int64)
X_test = full_test[features]
Y_test = full_test['billboard_hit'].apply(np.int64)

dt = c.fit(X_train, Y_train)
y_pred = c.predict(X_test)
score = accuracy_score(Y_test, y_pred) * 100
print("Decision Tree Accuracy: ", score)


from sklearn.linear_model import LogisticRegression
model = LogisticRegression()
model.fit(X_train, Y_train)
model.predict(X_test)
print("Logistic Regression Accuracy: ",model.score(X_test, Y_test))

from sklearn.ensemble import RandomForestClassifier
model = RandomForestClassifier(n_estimators = 100)
model.fit(X_train, Y_train)
print("Random Forest Accuracy: ",model.score(X_test, Y_test))
Y_predicted = model.predict(X_test)
cm = confusion_matrix(Y_test, Y_predicted)
print(cm)

model = SVC()
model.fit(X_train, Y_train)
print("SVM Accuracy: ",model.score(X_test, Y_test))
